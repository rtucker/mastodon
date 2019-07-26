module AutorejectHelper
  LOG_SCOPE_FEDERATION = ENV.fetch('LOG_SCOPE_FEDERATION', 'federation')

	def should_reject?(uri = nil)
    if uri.nil?
      if @object
        uri = object_uri.start_with?('http') ? object_uri : @object['url']
      elsif @json
        uri = @json['id']
      end
    end

    return if uri.nil?

    domain = uri.scan(/[\w\-]+\.[\w\-]+(?:\.[\w\-]+)*/).first
    blocks = DomainBlock.suspend
    reason = ((@json && @json['type'] == 'Announce') ? :domain_boost : :domain)
    return reason if blocks.where(domain: domain).or(blocks.where('domain LIKE ?', "%.#{domain}")).exists?

    return unless @json || @object

    context = @object['@context'] if @object

    if @json
      oid = @json['id']
      if oid
        return :id_starts_with if ENV.fetch('REJECT_IF_ID_STARTS_WITH', '').split.any? { |r| oid.start_with?(r) }
        return :id_contains if ENV.fetch('REJECT_IF_ID_CONTAINS', '').split.any? { |r| r.in?(oid) }
      end

      username = @json['preferredUsername'] || @json['username']
      if username && username.is_a?(String)
        username = (@json['actor'] && @json['actor'].is_a?(String)) ? @json['actor'] : ''
        username = username.scan(/(?<=\/user\/|\/@|\/users\/)([^\s\/]+)/).first
      end

      unless username.blank?
        username.downcase!
        return :username if ENV.fetch('REJECT_IF_USERNAME_EQUALS', '').split.any? { |r| r == username }
        return :username_starts_with if ENV.fetch('REJECT_IF_USERNAME_STARTS_WITH', '').split.any? { |r| username.start_with?(r) }
        return :username_contains if ENV.fetch('REJECT_IF_USERNAME_CONTAINS', '').split.any? { |r| r.in?(username) }
      end

      context = @json['@context'] unless @object && context
    end

    return unless context

    if context.is_a?(Array)
      inline_context = context.find { |item| item.is_a?(Hash) }
      if inline_context
        keys = inline_context.keys
        return :context if ENV.fetch('REJECT_IF_CONTEXT_EQUALS', '').split.any? { |r| r.in?(keys) }
        return :context_starts_with if ENV.fetch('REJECT_IF_CONTEXT_STARTS_WITH', '').split.any? { |r| keys.any? { |k| k.start_with?(r) } }
        return :context_contains if ENV.fetch('REJECT_IF_CONTEXT_CONTAINS', '').split.any? { |r| keys.any? { |k| r.in?(k) } }
      end
    end

    nil
  end

  def reject_reason(reason)
    case reason
    when :domain
      "the origin domain is blocked"
    when :domain_boost
      "the origin domain of the object being boosted is blocked"
    when :id_starts_with
      "the object's URI starts with a blocked phrase"
    when :id_contains
      "the object's URI contains a blocked phrase"
    when :username
      "the author's username is blocked"
    when :username_starts_with
      "the author's username starts with a blocked phrase"
    when :username_contains
      "the author's username contains a blocked phrase"
    when :context
      "the object's JSON-LD context has a key matching a blocked phrase"
    when :context_starts_with
      "the object's JSON-LD context has a key starting with a blocked phrase"
    when :context_contains
      "the object's JSON-LD context has a key containing a blocked phrase"
    else
      "of an undefined reason"
    end
  end

  def autoreject?(uri = nil)
    return false if @options && @options[:imported]
    reason = should_reject?(uri)
    if reason
      reason = reject_reason(reason)
      if @json
        Rails.logger.info("Auto-rejected #{@json['id']} (#{@json['type']})")
        LogWorker.perform_async("\xf0\x9f\x9a\xab Auto-rejected an incoming '#{@json['type']}#{@object && " #{@object['type']}".rstrip}' from #{@json['id']} because #{reason}.", LOG_SCOPE_FEDERATION)
      elsif uri
        Rails.logger.info("Auto-rejected #{uri}")
        LogWorker.perform_async("\xf0\x9f\x9a\xab Auto-rejected a request to #{uri} because #{reason}.", LOG_SCOPE_FEDERATION)
      end
      return true
    end
    false
  end
end
