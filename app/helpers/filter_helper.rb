module FilterHelper
  include Redisable

	def phrase_filtered?(status, receiver_id, context)
    if redis.sismember("filtered_statuses:#{receiver_id}", status.id)
      return !(redis.hexists("custom_cw:#{receiver_id}", status.id) || redis.hexists("custom_cw:#{receiver_id}", "c#{status.conversation_id}"))
    end

    filters = cached_filters(receiver_id)
    filters.select! { |filter| filter.context.include?(context.to_s) && !filter.expired? }

    if status.media_attachments.any?
      filters.delete_if { |filter| filter.exclude_media }
    else
      filters.delete_if { |filter| filter.media_only }
    end

    return false if filters.empty?

    status = status.reblog if status.reblog?
    status_text = Formatter.instance.plaintext(status)
    spoiler_text = status.spoiler_text
    tags = status.tags.pluck(:name).join("\n")

    filters.each do |filter|
      if filter.whole_word
        sb = filter.phrase =~ /\A[[:word:]]/ ? '\b' : ''
        eb = filter.phrase =~ /[[:word:]]\z/ ? '\b' : ''

        regex = /(?mix:#{sb}#{Regexp.escape(filter.phrase)}#{eb})/
      else
        regex = /#{Regexp.escape(filter.phrase)}/i
      end

      matched = false
      matched = true unless regex.match(status_text).nil?
      matched = true unless spoiler_text.blank? || regex.match(spoiler_text).nil?
      matched = true unless tags.empty? || regex.match(tags).nil?

      if matched
        filter_thread(receiver_id, status.conversation_id) if filter.thread && filter.custom_cw.blank?

        unless filter.custom_cw.blank?
          cw = if filter.override_cw || status.spoiler_text.blank?
                 filter.custom_cw
               else
                 "[#{filter.custom_cw}] #{status.spoiler_text}".rstrip
               end

          if filter.thread
            redis.hset("custom_cw:#{receiver_id}", "c#{status.conversation_id}", cw)
          else
            redis.hset("custom_cw:#{receiver_id}", status.id, cw)
          end
        end

        redis.sadd("filtered_statuses:#{receiver_id}", status.id)
        return filter.custom_cw.blank?
      end
    end

    false
  end

  def filter_thread(account_id, conversation_id)
    return if Status.where(account_id: account_id, conversation_id: conversation_id).exists?
    redis.sadd("filtered_threads:#{account_id}", conversation_id)
  end

  def filtering_thread?(account_id, conversation_id)
    redis.sismember("filtered_threads:#{account_id}", conversation_id)
  end

  def cached_filters(account_id)
    Rails.cache.fetch("filters:#{account_id}") { CustomFilter.where(account_id: account_id).to_a }.to_a
  end
end
