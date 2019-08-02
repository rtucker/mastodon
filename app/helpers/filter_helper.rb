module FilterHelper
	def phrase_filtered?(status, receiver_id, context)
    filters = Rails.cache.fetch("filters:#{receiver_id}") { CustomFilter.where(account_id: receiver_id).active_irreversible.to_a }.to_a

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
      matched = true unless tags.empty? || tags_regex.match(tags).nil?

      if matched
        filter_thread(receiver_id, status.conversation_id) if filter.thread
        return true
      end
    end

    false
  end

  def filter_thread(account_id, conversation_id)
    return if Status.where(account_id: account_id, conversation_id: conversation_id).exists?
    Redis.current.sadd("filtered_threads:#{account_id}", conversation_id)
  end

  def filtering_thread?(account_id, conversation_id)
    Redis.current.sismember("filtered_threads:#{account_id}", conversation_id)
  end
end
