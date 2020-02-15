# frozen_string_literal: true

class FavouriteService < BaseService
  include Authorization
  include Payloadable

  # Favourite a status and notify remote user
  # @param [Account] account
  # @param [Status] status
  # @return [Favourite]
  def call(account, status, skip_notify: false, skip_authorize: false)
    authorize_with account, status, :favourite? unless skip_authorize

    favourite = Favourite.find_by(account: account, status: status)

    return favourite unless favourite.nil?

    account.mark_known! if account.can_be_marked_known? && Setting.mark_known_from_favourites
    favourite = Favourite.create!(account: account, status: status)

    curate_status(status)
    create_notification(favourite) unless skip_notify
    bump_potential_friendship(account, status)

    favourite
  end

  private

  def create_notification(favourite)
    status = favourite.status

    if status.account.local?
      NotifyService.new.call(status.account, favourite)
    else
      ActivityPub::DeliveryWorker.perform_async(build_json(favourite), favourite.account_id, status.account.inbox_url)
    end
  end

  def bump_potential_friendship(account, status)
    ActivityTracker.increment('activity:interactions')
    return if account.following?(status.account_id)
    PotentialFriendshipTracker.record(account.id, status.account_id, :favourite)
  end

  def build_json(favourite)
    Oj.dump(serialize_payload(favourite, ActivityPub::LikeSerializer))
  end

  def curate_status(status)
    return if status.curated || !status.distributable? || (status.reply? && status.in_reply_to_account_id != status.account_id)
    status.update(curated: true)
    FanOutOnWriteService.new.call(status)
  end
end
