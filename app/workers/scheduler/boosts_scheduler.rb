# frozen_string_literal: true

class Scheduler::BoostsScheduler
  include Sidekiq::Worker
  include Redisable

  sidekiq_options unique: :until_executed, retry: 0

  def perform
    process_queued_boosts!
  end

  private

  def process_queued_boosts!
    queued_accounts.find_each do |account|
      next if redis.exists("queued_boost:#{account.id}") || account&.user.nil?

      q = next_boost(account.id, account.user.boost_random?)
      next if q.empty?

      from_interval = account.user.boost_interval_from
      to_interval = account.user.boost_interval_to

      if from_interval > to_interval
        from_interval, to_interval = [to_interval, from_interval]
      end

      interval = rand(from_interval .. to_interval).minutes

      redis.setex("queued_boost:#{account.id}", interval, 1)

      begin
        ReblogStatusWorker.perform_async(account.id, q.first.status_id, distribute: true)
      rescue Mastodon::NotPermittedError
        false
      ensure
        q.destroy_all
      end
    end
  end

  def queued_accounts
    Account.where(id: queued_account_ids)
  end

  def queued_account_ids
    QueuedBoost.distinct.pluck(:account_id)
  end

  def next_boost(account_id, boost_random = false)
    q = QueuedBoost.where(account_id: account_id)
    (boost_random ? q.order(Arel.sql('RANDOM()')) : q.order(:id)).limit(1)
  end
end
