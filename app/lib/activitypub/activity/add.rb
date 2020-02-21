# frozen_string_literal: true

class ActivityPub::Activity::Add < ActivityPub::Activity
  def perform
    return unless @json['target'].present? && value_or_id(@json['target']) == @account.featured_collection_url

    status   = status_from_uri(object_uri)
    if @account.known?
      status ||= fetch_remote_original_status(announced_by: @account)
    end

    return unless !status.nil? && status.account_id == @account.id && !@account.pinned?(status)

    StatusPin.create!(account: @account, status: status)
  end
end
