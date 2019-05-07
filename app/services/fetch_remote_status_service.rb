# frozen_string_literal: true

class FetchRemoteStatusService < BaseService
  def call(url, prefetched_body = nil)
    if prefetched_body.nil?
      resource_url, resource_options = FetchAtomService.new.call(url)
    else
      resource_url     = url
      resource_options = { prefetched_body: prefetched_body }
    end

    return if resource_url.blank?
    ActivityPub::FetchRemoteStatusService.new.call(resource_url, **resource_options)
  end
end
