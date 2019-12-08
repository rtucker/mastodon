# frozen_string_literal: true

require_relative '../../config/boot'
require_relative '../../config/environment'
require_relative 'cli_helper'

module Mastodon
  class MediaCLI < Thor
    include ActionView::Helpers::NumberHelper

    def self.exit_on_failure?
      true
    end

    option :days, type: :numeric, default: 7
    option :background, type: :boolean, default: false
    option :verbose, type: :boolean, default: false
    option :dry_run, type: :boolean, default: false
    desc 'remove', 'Remove remote media files'
    long_desc <<-DESC
      Removes locally cached copies of media attachments from other servers.

      The --days option specifies how old media attachments have to be before
      they are removed. It defaults to 7 days.
    DESC
    def remove
      time_ago = options[:days].days.ago
      dry_run  = options[:dry_run] ? '(DRY RUN)' : ''

      processed, aggregate = parallelize_with_progress(MediaAttachment.cached.where.not(remote_url: '').where('created_at < ?', time_ago)) do |media_attachment|
        next if media_attachment.file.blank?

        size = media_attachment.file_file_size

        unless options[:dry_run]
          media_attachment.file.destroy
          media_attachment.save
        end

        size
      end

      say("Removed #{processed} media attachments (approx. #{number_to_human_size(aggregate)}) #{dry_run}", :green, true)
    end

    option :start_after
    option :dry_run, type: :boolean, default: false
    desc 'remove-orphans', 'Scan storage and check for files that do not belong to existing media attachments'
    long_desc <<~LONG_DESC
      Scans file storage for files that do not belong to existing media attachments. Because this operation
      requires iterating over every single file individually, it will be slow.

      Please mind that some storage providers charge for the necessary API requests to list objects.
    LONG_DESC
    def remove_orphans
      progress        = create_progress_bar(nil)
      reclaimed_bytes = 0
      removed         = 0
      dry_run         = options[:dry_run] ? ' (DRY RUN)' : ''

      case Paperclip::Attachment.default_options[:storage]
      when :s3
        paperclip_instance = MediaAttachment.new.file
        s3_interface       = paperclip_instance.s3_interface
        bucket             = s3_interface.bucket(Paperclip::Attachment.default_options[:s3_credentials][:bucket])
        last_key           = options[:start_after]

        loop do
          objects = bucket.objects(start_after: last_key, prefix: 'media_attachments/files/').limit(1000).map { |x| x }

          break if objects.empty?

          last_key        = objects.last.key
          attachments_map = MediaAttachment.where(id: objects.map { |object| object.key.split('/')[2..-2].join.to_i }).each_with_object({}) { |attachment, map| map[attachment.id] = attachment }

          objects.each do |object|
            attachment_id = object.key.split('/')[2..-2].join.to_i
            filename      = object.key.split('/').last

            progress.increment

            next unless attachments_map[attachment_id].nil? || !attachments_map[attachment_id].variant?(filename)

            reclaimed_bytes += object.size
            removed += 1
            object.delete unless options[:dry_run]
            progress.log("Found and removed orphan: #{object.key}")
          end
        end
      when :fog
        say('The fog storage driver is not supported for this operation at this time', :red)
        exit(1)
      when :filesystem
        require 'find'

        root_path = ENV.fetch('RAILS_ROOT_PATH', File.join(':rails_root', 'public', 'system')).gsub(':rails_root', Rails.root.to_s)

        Find.find(File.join(root_path, 'media_attachments', 'files')) do |path|
          next if File.directory?(path)

          key           = path.gsub("#{root_path}#{File::SEPARATOR}", '')
          attachment_id = key.split(File::SEPARATOR)[2..-2].join.to_i
          filename      = key.split(File::SEPARATOR).last
          attachment    = MediaAttachment.find_by(id: attachment_id)

          progress.increment

          next unless attachment.nil? || !attachment.variant?(filename)

          reclaimed_bytes += File.size(path)
          removed += 1
          File.delete(path) unless options[:dry_run]
          progress.log("Found and removed orphan: #{key}")
        end
      end

      progress.total = progress.progress
      progress.finish

      say("Removed #{removed} orphans (approx. #{number_to_human_size(reclaimed_bytes)})#{dry_run}", :green, true)
    end

    option :account, type: :string
    option :domain, type: :string
    option :status, type: :numeric
    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :verbose, type: :boolean, default: false, aliases: [:v]
    option :dry_run, type: :boolean, default: false
    option :force, type: :boolean, default: false
    desc 'refresh', 'Fetch remote media files'
    long_desc <<-DESC
      Re-downloads media attachments from other servers. You must specify the
      source of media attachments with one of the following options:

      Use the --status option to download attachments from a specific status,
      using the status local numeric ID.

      With the --background option, instead of deleting the files sequentially,
      they will be queued into Sidekiq and the command will exit as soon as
      possible. In Sidekiq they will be processed with higher concurrency, but
      it may impact other operations of the Mastodon server, and it may overload
      the underlying file storage.

      With the --dry-run option, no work will be done.

      With the --verbose option, when media attachments are processed sequentially in the
      foreground, the IDs of the media attachments will be printed.
    DESC
    def remove
      time_ago  = options[:days].days.ago
      queued    = 0
      processed = 0
      size      = 0
      dry_run   = options[:dry_run] ? '(DRY RUN)' : ''

      if options[:background]
        MediaAttachment.where.not(remote_url: '').where.not(file_file_name: nil).where('created_at < ?', time_ago).select(:id, :file_file_size).reorder(nil).find_in_batches do |media_attachments|
          queued += media_attachments.size
          size   += media_attachments.reduce(0) { |sum, m| sum + (m.file_file_size || 0) }
          Maintenance::UncacheMediaWorker.push_bulk(media_attachments.map(&:id)) unless options[:dry_run]
        end
      else
        MediaAttachment.where.not(remote_url: '').where.not(file_file_name: nil).where('created_at < ?', time_ago).reorder(nil).find_in_batches do |media_attachments|
          media_attachments.each do |m|
            size += m.file_file_size || 0
            Maintenance::UncacheMediaWorker.new.perform(m) unless options[:dry_run]
            options[:verbose] ? say(m.id) : say('.', :green, false)
            processed += 1
          end
        end
      end

      say

      if options[:background]
        say("Scheduled the deletion of #{queued} media attachments (approx. #{number_to_human_size(size)}) #{dry_run}", :green, true)
      else
        say("Removed #{processed} media attachments (approx. #{number_to_human_size(size)}) #{dry_run}", :green, true)
      end
    end
  end
end
