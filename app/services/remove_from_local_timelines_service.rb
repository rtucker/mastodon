# frozen_string_literal: true

class RemoveFromLocalTimelinesService < BaseService
  include Redisable

  def call(status)
    @payload      = Oj.dump(event: :delete, payload: status.id.to_s)
    @status       = status
    @account      = status.account
    @tags         = status.tags.pluck(:name).to_a
    @mentions     = status.active_mentions.includes(:account).to_a
    @reblogs      = status.reblogs.includes(:account).to_a

    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        remove_from_self if status.account.local?
        remove_from_followers
        remove_from_lists
        remove_from_affected
        remove_from_hashtags
        remove_from_public
        remove_from_media if status.media_attachments.any?
        remove_from_direct if status.direct_visibility?
      else
        raise Mastodon::RaceConditionError
      end
    end
  end

  private

  def remove_from_self
    FeedManager.instance.unpush_from_home(@account, @status)
  end

  def remove_from_followers
    @account.followers_for_local_distribution.reorder(nil).find_each do |follower|
      FeedManager.instance.unpush_from_home(follower, @status)
    end
  end

  def remove_from_lists
    @account.lists_for_local_distribution.select(:id, :account_id).reorder(nil).find_each do |list|
      FeedManager.instance.unpush_from_list(list, @status)
    end
  end

  def remove_from_affected
    @mentions.map(&:account).select(&:local?).each do |account|
      redis.publish("timeline:#{account.id}", @payload)
    end
  end

  def remove_from_hashtags
    return unless @status.distributable?
    @tags.each do |hashtag|
      redis.publish("timeline:hashtag:#{hashtag}", @payload)
      redis.publish("timeline:hashtag:#{hashtag}:local", @payload) if @status.local?
    end
  end

  def remove_from_public
    return unless @status.distributable?
    redis.publish('timeline:public', @payload)
    redis.publish('timeline:public:local', @payload) if @status.local?
  end

  def remove_from_media
    return unless @status.distributable?
    redis.publish('timeline:public:media', @payload)
    redis.publish('timeline:public:local:media', @payload) if @status.local?
  end

  def remove_from_direct
    @mentions.each do |mention|
      Redis.current.publish("timeline:direct:#{mention.account.id}", @payload) if mention.account.local?
    end
    Redis.current.publish("timeline:direct:#{@account.id}", @payload) if @account.local?
  end

  def lock_options
    { redis: Redis.current, key: "distribute:#{@status.id}" }
  end
end
