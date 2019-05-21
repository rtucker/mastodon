# frozen_string_literal: true

require 'csv'

class ImportService < BaseService
  include RoutingHelper
  include JsonLdHelper

  ROWS_PROCESSING_LIMIT = 20_000
  CONTENT_TYPES = %w(text/bbcode+markdown text/markdown text/bbcode text/html text/plain).freeze
  VISIBILITIES = [:public, :unlisted, :private, :direct, :limited].freeze
  IMPORT_STATUS_ATTRIBUTES = [
    'id',
    'content_type',
    'spoiler_text',
    'text',
    'footer',
    'in_reply_to_id',
    'reply',
    'reblog_of_id',
    'created_at',
    'conversation_id',
    'sensitive',
    'language',
    'local_only',
    'visibility',
  ].freeze

  def call(import)
    @import  = import
    @account = @import.account

    case @import.type
    when 'following'
      import_follows!
    when 'blocking'
      import_blocks!
    when 'muting'
      import_mutes!
    when 'domain_blocking'
      import_domain_blocks!
    when 'statuses'
      import_statuses!
    end
  end

  private

  def import_follows!
    parse_import_data!(['Account address'])
    import_relationships!('follow', 'unfollow', @account.following, follow_limit, reblogs: 'Show boosts')
  end

  def import_blocks!
    parse_import_data!(['Account address'])
    import_relationships!('block', 'unblock', @account.blocking, ROWS_PROCESSING_LIMIT)
  end

  def import_mutes!
    parse_import_data!(['Account address'])
    import_relationships!('mute', 'unmute', @account.muting, ROWS_PROCESSING_LIMIT, notifications: 'Hide notifications')
  end

  def import_domain_blocks!
    parse_import_data!(['#domain'])
    items = @data.take(ROWS_PROCESSING_LIMIT).map { |row| row['#domain'].strip }

    if @import.overwrite?
      presence_hash = items.each_with_object({}) { |id, mapping| mapping[id] = true }

      @account.domain_blocks.find_each do |domain_block|
        if presence_hash[domain_block.domain]
          items.delete(domain_block.domain)
        else
          @account.unblock_domain!(domain_block.domain)
        end
      end
    end

    items.each do |domain|
      @account.block_domain!(domain)
    end

    AfterAccountDomainBlockWorker.push_bulk(items) do |domain|
      [@account.id, domain]
    end
  end

  def import_statuses!
    parse_import_data_json!
    return if @data.nil?
    if @import.overwrite?
      @account.statuses.without_reblogs.reorder(nil).find_in_batches do |statuses|
        BatchedRemoveStatusService.new.call(statuses)
      end
    end
    return import_activitypub if @data.kind_of?(Hash) && @data['orderedItems'].present?
    return unless @data.kind_of?(Array)
    import_json_statuses
  end

  def import_json_statuses
    @account.vars['_bangtags:disable'] = true
    @account.save

    @data.each do |json|
      # skip if invalid status object
      next if json.nil?
      next unless json.kind_of?(Hash)
      json.slice!(*IMPORT_STATUS_ATTRIBUTES)
      json.compact!
      next if json.blank?

      # skip if missing reblog
      unless json['reblog_of_id'].nil?
        json['reblog_of_id'] = json['reblog_of_id'].to_i
        next unless (json['reblog_of_id'] != 0 ? Status.where(id: json['reblog_of_id']).exists? : false)
      end

      # convert iso8601 strings to DateTime object
      json['created_at'] = json['created_at'].kind_of?(String) ? DateTime.iso8601(json['created_at']).utc : Time.now.utc

      if json['id'].blank?
        json['id'] = nil
      else
        # make sure id is an integer
        status_id = json['id'].to_i
        json['id'] = status_id != 0 ? status_id : nil

        # check for duplicate
        existing_status = Status.find_by_id(json['id'])
        unless existing_status.nil?
          # skip if duplicate
          next if (json['created_at'] - existing_status.created_at).abs < 1
          # else drop the conflicting id value
          json['id'] = nil
        end
      end

      # ensure correct values & value types
      json['content_type'] = 'text/plain' unless CONTENT_TYPES.include?(json['content_type'])
      json['spoiler_text'] = '' unless json['spoiler_text'].kind_of?(String)
      json['text'] = '' unless json['text'].kind_of?(String)
      json['footer'] = nil unless json['footer'].kind_of?(String)
      json['reply'] = [true, 1, "1"].include?(json['reply'])
      json['in_reply_to_id'] = json['in_reply_to_id'].to_i unless json['in_reply_to_id'].nil?
      json['conversation_id'] = json['conversation_id'].to_i unless json['conversation_id'].nil?
      json['sensitive'] = [true, 1, "1"].include?(json['sensitive'])
      json['language'] = 'en' unless json['language'].kind_of?(String) && json['language'].length > 1
      json['language'] = ISO_639.find(json['language'])&.alpha2 || @account.user_default_language&.presence || 'en'
      json['local_only'] = @account.user_always_local_only? || [true, 1, "1"].include?(json['local_only'])
      json['visibility'] = VISIBILITIES[json['visibility'].to_i] || :unlisted
      json['imported'] = true

      # drop a nonexistant conversation id
      unless (json['conversation_id'] != 0 ? Conversation.where(id: json['conversation_id']).exists? : false)
        json['conversation_id'] = nil
      end

      # nullify a missing reply
      unless (json['in_reply_to_id'] != 0 ? Status.where(id: json['in_reply_to_id']).exists? : false)
        json['in_reply_to_id'] = nil
      end

      ApplicationRecord.transaction do
        status = @account.statuses.create!(json.compact.symbolize_keys)
        process_hashtags_service.call(status)
        process_mentions_service.call(status, skip_notify: true)
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, Mastodon::ValidationError => e
      Rails.logger.error "Error importing status (JSON): #{e}"
      nil
    end

    @account.vars.delete('_bangtags:disable')
    @account.save
  end

  def import_activitypub
    account_uri = ActivityPub::TagManager.instance.uri_for(@account)
    followers_uri = account_followers_url(@account)

    @data["orderedItems"].each do |activity|
      next if activity['object'].blank?
      next unless %w(Create Announce).include?(activity['type'])

      object = activity['object']
      activity['actor'] = account_uri

      activity['to'] = if activity['to'].kind_of?(Array)
                         activity['to'].uniq.map { |to| to.end_with?('/followers') ? followers_uri : to }
                       else
                         [account_uri]
                       end

      activity['cc'] = if activity['cc'].kind_of?(Array)
                         activity['cc'].uniq.map { |cc| cc.end_with?('/followers') ? followers_uri : cc }
                       else
                         []
                       end

      case activity['type']
      when 'Announce'
        next unless object.kind_of?(String)
      when 'Note'
        next unless object.kind_of?(Hash)
        object['attributedTo'] = account_uri
        object['to'] = activity['to']
        object['cc'] = activity['cc']
        object.delete('attachment')
      end

      activity = ActivityPub::Activity.factory(activity, @account, imported: true)
      activity&.perform
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, Mastodon::ValidationError, HTTP::ConnectionError, HTTP::TimeoutError, OpenSSL::SSL::SSLError, Paperclip::Errors::NotIdentifiedByImageMagickError, Addressable::URI::InvalidURIError, Mastodon::HostValidationError, Mastodon::LengthValidationError => e
      Rails.logger.error "Error importing status (ActivityPub): #{e}"
      nil
    end
  end

  def import_relationships!(action, undo_action, overwrite_scope, limit, extra_fields = {})
    items = @data.take(limit).map { |row| [row['Account address']&.strip, Hash[extra_fields.map { |key, header| [key, row[header]&.strip] }]] }.reject { |(id, _)| id.blank? }

    if @import.overwrite?
      presence_hash = items.each_with_object({}) { |(id, extra), mapping| mapping[id] = [true, extra] }

      overwrite_scope.find_each do |target_account|
        if presence_hash[target_account.acct]
          items.delete(target_account.acct)
          extra = presence_hash[target_account.acct][1]
          Import::RelationshipWorker.perform_async(@account.id, target_account.acct, action, extra)
        else
          Import::RelationshipWorker.perform_async(@account.id, target_account.acct, undo_action)
        end
      end
    end

    Import::RelationshipWorker.push_bulk(items) do |acct, extra|
      [@account.id, acct, action, extra]
    end
  end

  def parse_import_data!(default_headers)
    data = CSV.parse(import_data, headers: true)
    data = CSV.parse(import_data, headers: default_headers) unless data.headers&.first&.strip&.include?(' ')
    @data = data.reject(&:blank?)
  rescue CSV::MalformedCSVError
    @data = nil
  end

  def parse_import_data_json!
    @data = Oj.load(import_data, mode: :strict)
  rescue Oj::ParseError
    @data = []
  end

  def import_data
    Paperclip.io_adapters.for(@import.data).read
  end

  def follow_limit
    FollowLimitValidator.limit_for_account(@account)
  end

  def process_mentions_service
    ProcessMentionsService.new
  end

  def process_hashtags_service
    ProcessHashtagsService.new
  end
end
