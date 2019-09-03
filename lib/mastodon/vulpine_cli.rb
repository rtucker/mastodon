# frozen_string_literal: true

# VulpineClub local functions

require 'set'
require_relative '../../config/boot'
require_relative '../../config/environment'
require_relative 'cli_helper'

module Mastodon
  class VulpineCLI < Thor
    def self.exit_on_failure?
      true
    end

    desc 'skclean', 'Clean up the Sidekiq dead queue'
    long_desc <<-LONG_DESC
      Cleans up the following classes of items in the Sidekiq
      dead queue:

      - ThreadResolveWorker
      - ResolveAccountWorker
      - LinkCrawlWorker

      Also:

      - ActiveRecord::RecordNotFound errors
    LONG_DESC
    def skclean
      ds = Sidekiq::DeadSet.new

      jobs = ds.select do |job|
          job.item['class'] == 'ThreadResolveWorker' ||
          job.item['class'] == 'ResolveAccountWorker' ||
          job.item['class'] == 'LinkCrawlWorker' ||
          job.item['error_class'] == 'ActiveRecord::RecordNotFound'
      end

      say("Deleting #{jobs.size} out of #{ds.size}...", :green)

      jobs.each(&:delete)
    end

    desc 'sknecro', 'Retry all jobs in the Sidekiq dead queue'
    def sknecro
      ds = Sidekiq::DeadSet.new

      jobs = ds

      say("Retrying #{jobs.size}", :green, false)

      jobs.each do |job|
        sleep 1
        job.retry
        say('.', nil, false)
      end

      say
    end

    desc 'skpush [DOMAIN]', 'Retry all jobs for a particular instance'
    def skpush(domain = nil)
      if domain.nil?
        say('No domain given', :red)
        exit(1)
      end

      rs = Sidekiq::RetrySet.new

      jobs = rs.select {|j| j.value.include? "https://#{domain}"}

      say("Retrying #{jobs.size} from #{domain}", :green)

      jobs.map {|j| j.item['args'][2]}.uniq.each do |inbox|
        say("Inbox: #{inbox} ", :green, false)

        inbox_jobs = jobs.select {|x| x.item['args'][2] == "#{inbox}"}

        inbox_jobs.each do |job|
          sleep 1

          light = Stoplight(inbox)

          if light.color == "green"
            job.retry
            say('.', :green, false)
          elsif light.color == "yellow"
            say('!', :yellow, false)
          else
            say('x', :red)
            next
          end
        end

        say
      end
    end

    desc 'skdomains', 'List instances with retries, and how many'
    def skdomains
      rs = Sidekiq::RetrySet.new

      jobs = rs.select {|j| j.item['class'] == 'ActivityPub::DeliveryWorker'}

      say("AP::DeliveryWorker count: #{jobs.size}, out of #{rs.size}")

      reds = []
      greens = []

      jobs.map {|j| j.item['args'][2]}.uniq.each do |inbox|
        inbox_jobs = jobs.select {|x| x.item['args'][2] == "#{inbox}"}

        light = Stoplight(inbox)

        if color(light.color) == :green
          greens << inbox_jobs.size
        else
          reds << inbox_jobs.size
        end

        say("#{inbox}: job count #{inbox_jobs.size}, color #{light.color}", color(light.color))
      end

      say
      say("Red domains: #{reds.size}, total job count: #{reds.sum}")
      say("Green domains: #{greens.size}, total job count: #{greens.sum}")
    end

    desc 'orphanmedia', 'List orphaned media files'
    def orphanmedia
      l = Array.new
      mypath = ENV["PAPERCLIP_ROOT_PATH"] + '/media_attachments'
      getFilesRecursive(mypath) do |item|
        if MediaAttachment.where.not(file_file_name: File.basename(item))
          l.push(item)
          say('x', :red, false)
        else
          say('.', :green, false)
        end
      end

      say

      l do |item|
        puts "rm #{item}"
      end
    end

    private

    def color(str)
      if str == "green"
        :green
      else
        :red
      end
    end

    def getFilesRecursive(path)
      # borrowed from stack overflow: https://stackoverflow.com/questions/9618424/best-way-to-recursively-find-all-files-rest-api

      # create our directory object and file list storage
      d = Dir.new(path)
      l = Array.new

      # iterate over our given directory
      d.each do |f|
        next if f == '.' or f == '..'

        # recurse on a directory
        if File.directory?(path + '/' + f)
          l += getFilesRecursive(path + '/' + f)
        # store on a file
        else
          l.push(path + '/' + f)
        end

      end # Dir.each

      # return our list of files
      return l

    end # getFilesRecursive()

  end
end
