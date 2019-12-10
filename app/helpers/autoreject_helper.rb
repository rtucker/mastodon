module AutorejectHelper
  include ModerationHelper

	def should_reject?(uri = nil)
    if uri.nil?
      if @object
        uri = object_uri.start_with?('http') ? object_uri : @object['url']
      elsif @json
        uri = @json['id']
      end
    end

    return if uri.nil?
    return unless @json || @object

    domain = uri.scan(/[\w\-]+\.[\w\-]+(?:\.[\w\-]+)*/).first
    blocks = DomainBlock.suspend
    return [:domain, uri] if blocks.where(domain: domain).or(blocks.where('domain LIKE ?', "%.#{domain}")).exists?

    if @json
      oid = @json['id']
      if oid
        return [:id_starts_with, uri] if ENV.fetch('REJECT_IF_ID_STARTS_WITH', '').split.any? { |r| oid.start_with?(r) }
        return [:id_contains, uri] if ENV.fetch('REJECT_IF_ID_CONTAINS', '').split.any? { |r| r.in?(oid) }
      end

      username = @json['preferredUsername'] || @json['username']
      if username && username.is_a?(String)
        username = (@json['actor'] && @json['actor'].is_a?(String)) ? @json['actor'] : ''
        username = username.scan(/(?<=\/user\/|\/@|\/users\/)([^\s\/]+)/).first
      end

      unless username.blank?
        username.downcase!
        return [:username, uri] if ENV.fetch('REJECT_IF_USERNAME_EQUALS', '').split.any? { |r| r == username }
        return [:username_starts_with, uri] if ENV.fetch('REJECT_IF_USERNAME_STARTS_WITH', '').split.any? { |r| username.start_with?(r) }
        return [:username_contains, uri] if ENV.fetch('REJECT_IF_USERNAME_CONTAINS', '').split.any? { |r| r.in?(username) }
      end
    end

    nil
  end

  def reject_reason(reason)
    case reason
    when :domain
      "the origin domain is blocked"
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
    else
      "of an undefined reason"
    end
  end

  def autoreject?(uri = nil)
    return false if @options && @options[:imported]
    reason, uri = should_reject?(uri)
    if reason
      reason = reject_reason(reason)
      if @json
        Rails.logger.info("Rejected an incoming '#{@json['type']}#{@object && " #{@object['type']}".rstrip}' from #{@json['id']} because #{reason}.")
      elsif uri
        Rails.logger.info("Rejected an outgoing request to #{uri} because #{reason}.")
      end
      return true
    end
    false
  end
end
