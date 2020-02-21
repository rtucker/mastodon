# frozen_string_literal: true

class ActivityPub::FetchRemoteAccountService < BaseService
  include JsonLdHelper
  include AutorejectHelper
  include DomainControlHelper

  SUPPORTED_TYPES = %w(Application Group Organization Person Service).freeze

  # Does a WebFinger roundtrip on each call, unless `only_key` is true
  def call(uri, id: true, prefetched_body: nil, break_on_redirect: false, only_key: false)
    return if domain_not_allowed?(uri)
    return ActivityPub::TagManager.instance.uri_to_resource(uri, Account) if ActivityPub::TagManager.instance.local_uri?(uri)

    @json = begin
      if prefetched_body.nil?
        fetch_resource(uri, id)
      else
        body_to_json(prefetched_body, compare_id: id ? uri : nil)
      end
    end

    return if !supported_context? || !expected_type? || (break_on_redirect && @json['movedTo'].present?)

    @uri      = @json['id']
    @username = @json['preferredUsername']
    @domain   = Addressable::URI.parse(@uri).normalized_host

    return unless only_key || verified_webfinger?

    ActivityPub::ProcessAccountService.new.call(@username, @domain, @json, only_key: only_key)
  rescue Oj::ParseError
    nil
  end

  private

  def verified_webfinger?
    webfinger                            = Goldfinger.finger("acct:#{@username}@#{@domain}")
    confirmed_username, confirmed_domain = split_acct(webfinger.subject)

    return webfinger.link('self')&.href == @uri if @username.casecmp(confirmed_username).zero? && @domain.casecmp(confirmed_domain).zero?

    webfinger                            = Goldfinger.finger("acct:#{confirmed_username}@#{confirmed_domain}")
    @username, @domain                   = split_acct(webfinger.subject)
    self_reference                       = webfinger.link('self')

    return false unless @username.casecmp(confirmed_username).zero? && @domain.casecmp(confirmed_domain).zero?
    return false if self_reference&.href != @uri

    true
  rescue Goldfinger::Error
    false
  end

  def split_acct(acct)
    acct.gsub(/\Aacct:/, '').split('@')
  end

  def supported_context?
    super(@json)
  end

  def expected_type?
    equals_or_includes_any?(@json['type'], SUPPORTED_TYPES)
  end

  def object_uri
    nil
  end
end
