module FilterHelper
  include Redisable

	def phrase_filtered?(status, receiver_id, skip_redis: false)
    return true if !skip_redis && redis.sismember("filtered_statuses:#{receiver_id}", status.id)
    return false unless CustomFilter.where(account_id: receiver_id, is_enabled: true).exists?

    status = status.reblog if status.reblog?

    if Status.where(id: status.id).search_filtered_by_account(receiver_id).exists?
      redis.sadd("filtered_statuses:#{receiver_id}", status.id) unless skip_redis
      return true
    end

    false
  end
end
