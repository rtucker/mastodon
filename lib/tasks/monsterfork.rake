# frozen_string_literal: true

namespace :monsterfork do
  desc "Re-apply all users' filters to their home and list timelines."
  task reapply_filters: :environment do
    Account.local.find_each do |account|
      Rails.logger.info("Re-applying filters for: #{account.username}")
      Redis.current.del("filtered_statuses:#{account.id}")
      FilterFeedsWorker.perform_async(account.id)
      sleep 1
      while Sidekiq::Queue.new.size > 5
        sleep 1
      end
    end
  end

  desc 'Mark known instance actors.'
  task mark_known_instance_actors: :environment do
    Rails.logger.info('Gathering known domains...')
    known_account_ids = Status.where(id: Status.local.reblogs.reorder(nil).select(:reblog_of_id)).reorder(nil).pluck(:account_id) |
                        Status.where(id: Favourite.select(:status_id)).reorder(nil).pluck(:account_id) |
                        Account.local.flat_map { |account| account.following_ids | account.follower_ids }

    known_domains = Account.select(:domain).distinct.where(id: known_account_ids).where.not(domain: nil).pluck(:domain)

    known_domains.each do |domain|
      instance_actor = Account.find_remote(domain, domain)
      next if instance_actor.nil?

      Rails.logger.info("Marking instance actor known for: #{domain}")
      instance_actor.update!(known: true)
    end
  end
end
