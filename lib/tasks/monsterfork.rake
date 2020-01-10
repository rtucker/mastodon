# frozen_string_literal: true

namespace :monsterfork do
  desc "Re-apply all users' filters to their home and list timelines."
  task reapply_filters: :environment do
    Account.local.find_each do |account|
      Rails.logger.info("Re-applying filters for: #{account.username}")
      FilterFeedsWorker.perform_async(account.id)
      sleep 1
      while Sidekiq::Queue.new.size > 5
        sleep 1
      end
    end
  end
end
