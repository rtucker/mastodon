# frozen_string_literal: true

class FetchRemoteStatusService < BaseService
  def call(url, prefetched_body = nil, announced_by: nil, requested: false)
    if prefetched_body.nil?
      resource_url, resource_options = FetchResourceService.new.call(url)
      resource_options = {} if resource_options.nil?
    else
      resource_url     = url
      resource_options = { prefetched_body: prefetched_body }
    end

    resource_options[:announced_by] = announced_by unless announced_by.nil?
    resource_options[:requested] = true if requested

    return if resource_url.blank?
    ActivityPub::FetchRemoteStatusService.new.call(resource_url, **resource_options)
  end
end
