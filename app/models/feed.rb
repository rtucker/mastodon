# frozen_string_literal: true

class Feed
  include Redisable

  def initialize(type, id)
    @type = type
    @id   = id
  end

  def get(limit, max_id = nil, since_id = nil, min_id = nil)
    from_redis(limit, max_id, since_id, min_id)
  end

  def size
    redis.zcount(key, '-inf', '+inf') || 0
  end

  def all
    unhydrated = redis.zrange(key, 0, -1, with_scores: true).map(&:first).map(&:to_i)
    Status.where(id: unhydrated)
  end

  def all_cached
    all.cache_ids
  end

  protected

  def from_redis(limit, max_id, since_id, min_id)
    if min_id.blank?
      max_id     = '+inf' if max_id.blank?
      since_id   = '-inf' if since_id.blank?
      unhydrated = redis.zrevrangebyscore(key, "(#{max_id}", "(#{since_id}", limit: [0, limit], with_scores: true).map(&:first).map(&:to_i)
    else
      unhydrated = redis.zrangebyscore(key, "(#{min_id}", '+inf', limit: [0, limit], with_scores: true).map(&:first).map(&:to_i)
    end

    Status.where(id: unhydrated).cache_ids
  end

  def key
    FeedManager.instance.key(@type, @id)
  end
end
