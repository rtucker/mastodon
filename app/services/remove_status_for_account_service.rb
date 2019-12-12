# frozen_string_literal: true

class RemoveStatusForAccountService < BaseService
  include Redisable

  def call(account, status)
    @account      = account
    @status       = status
    @payload      = Oj.dump(event: :delete, payload: status.id.to_s)

    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        remove_from_feeds
        remove_from_lists
      else
        raise Mastodon::RaceConditionError
      end
    end
  end

  private

  def remove_from_feeds
    FeedManager.instance.unpush_from_home(@account, @status)
    Redis.current.publish("timeline:direct:#{@account.id}", @payload)
    redis.publish("timeline:#{@account.id}", @payload)
  end

  def remove_from_lists
    @account.lists_for_local_distribution.select(:id, :account_id).reorder(nil).find_each do |list|
      FeedManager.instance.unpush_from_list(list, @status)
    end
  end

  def lock_options
    { redis: Redis.current, key: "distribute:#{@status.id}" }
  end
end
