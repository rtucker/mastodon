module AutorejectHelper
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
    return true if blocks.where(domain: domain).or(blocks.where('domain LIKE ?', "%.#{domain}")).exists?

    return unless @json || @object

    context = @object['@context'] if @object

    if @json
      oid = @json['id']
      if oid
        return true if ENV.fetch('REJECT_IF_ID_STARTS_WITH', '').split.any? { |r| oid.start_with?(r) }
        return true if ENV.fetch('REJECT_IF_ID_CONTAINS', '').split.any? { |r| r.in?(oid) }
      end

      username = @json['preferredUsername'] || @json['username']
      if username && username.is_a?(String)
        username = (@json['actor'] && @json['actor'].is_a?(String)) ? @json['actor'] : ''
        username = username.scan(/(?<=\/user\/|\/@|\/users\/)([^\s\/]+)/).first
      end

      unless username.blank?
        username.downcase!
        return true if ENV.fetch('REJECT_IF_USERNAME_EQUALS', '').split.any? { |r| r == username }
        return true if ENV.fetch('REJECT_IF_USERNAME_STARTS_WITH', '').split.any? { |r| username.start_with?(r) }
        return true if ENV.fetch('REJECT_IF_USERNAME_CONTAINS', '').split.any? { |r| r.in?(username) }
      end

      context = @json['@context'] unless @object && context
    end

    return unless context

    if context.is_a?(Array)
      inline_context = context.find { |item| item.is_a?(Hash) }
      if inline_context
        keys = inline_context.keys
        return true if ENV.fetch('REJECT_IF_CONTEXT_EQUALS', '').split.any? { |r| r.in?(keys) }
        return true if ENV.fetch('REJECT_IF_CONTEXT_STARTS_WITH', '').split.any? { |r| keys.any? { |k| k.start_with?(r) } }
        return true if ENV.fetch('REJECT_IF_CONTEXT_CONTAINS', '').split.any? { |r| keys.any? { |k| r.in?(k) } }
      end
    end

    false
  end

  def autoreject?(uri = nil)
    if (@options && @options[:imported]) || should_reject?(uri)
      Rails.logger.info("Auto-rejected #{@json['type']} activity #{@json['id']}")
      return true
    end
    false
  end
end
