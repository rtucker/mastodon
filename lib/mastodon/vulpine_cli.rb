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

      say("Retrying #{ds.size}", :green, false)

      ds.each do |job|
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
      else
        rs = Sidekiq::RetrySet.new

        jobs = rs.select {|j| j.value.include? "https://#{domain}"}

        say("Retrying #{jobs.size}", :green, false)

        rs.each do |job|
          sleep 1
          job.retry
          say('.', nil, false)
        end

        say
      end
    end
  end
end
