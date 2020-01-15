# frozen_string_literal: true

class ActivityPub::Activity::Follow < ActivityPub::Activity
  include Payloadable

  def perform
    return if autoreject?
    target_account = account_from_uri(object_uri)

    return if target_account.nil? || !target_account.local? || delete_arrived_first?(@json['id']) || @account.requested?(target_account)

    if (rejecting_unknown? && !known?) || target_account.blocking?(@account) || target_account.domain_blocking?(@account.domain) || target_account.moved?
      reject_follow_request!(target_account)
      return
    end

    if !target_account.user.allow_unknown_follows? && !(target_account.following?(@account) || ever_mentioned_by?(target_account))
      reject_follow_request!(target_account)
      return
    end

    # Fast-forward repeat follow requests
    if @account.following?(target_account)
      AuthorizeFollowService.new.call(@account, target_account, skip_follow_request: true, follow_request_uri: @json['id'])
      return
    end

    follow_request = FollowRequest.create!(account: @account, target_account: target_account, uri: @json['id'])

    if target_account.locked?
      NotifyService.new.call(target_account, follow_request)
    else
      AuthorizeFollowService.new.call(@account, target_account)
      NotifyService.new.call(target_account, ::Follow.find_by(account: @account, target_account: target_account))
    end
  end

  def reject_follow_request!(target_account)
    json = Oj.dump(serialize_payload(FollowRequest.new(account: @account, target_account: target_account, uri: @json['id']), ActivityPub::RejectFollowSerializer))
    ActivityPub::DeliveryWorker.perform_async(json, target_account.id, @account.inbox_url)
  endA

  private

  def ever_mentioned_by?(target_account)
    Status.joins(:mentions).merge(target_account.mentions).where(account_id: @account.id).exists?
  end
end
