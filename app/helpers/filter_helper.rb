module FilterHelper
  include Redisable

	def phrase_filtered?(status, receiver_id)
    return true if redis.sismember("filtered_statuses:#{receiver_id}", status.id)
    return false unless CustomFilter.where(account_id: receiver_id).exists?

    status = status.reblog if status.reblog?

    if Status.where(id: status.id).where("statuses.normalized_text ~ ANY(ARRAY(SELECT unaccent(lower(phrase)) FROM custom_filters WHERE account_id = ?))", receiver_id).exists?
      redis.sadd("filtered_statuses:#{receiver_id}", status.id)
      return true
    end

    false
  end
end
