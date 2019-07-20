# frozen_string_literal: true

class ReblogService < BaseService
  include Authorization
  include Payloadable

  # Reblog a status and notify its remote author
  # @param [Account] account Account to reblog from
  # @param [Status] reblogged_status Status to be reblogged
  # @param [Hash] options
  # @return [Status]
  def call(account, reblogged_status, options = {})
    reblogged_status = reblogged_status.reblog if reblogged_status.reblog?

    authorize_with account, reblogged_status, :reblog?

    reblog = account.statuses.find_by(reblog: reblogged_status)
    new_reblog = reblog.nil?

    if new_reblog
      reblogged_status.account.mark_known! unless !Setting.auto_mark_known || reblogged_status.account.known?
      reblogged_status.touch if reblogged_status.account.id == account.id

      visibility = options[:visibility] || account.user&.setting_default_privacy
      visibility = reblogged_status.visibility if reblogged_status.hidden?

      reblog = account.statuses.create!(reblog: reblogged_status, text: '', visibility: visibility)
    end
    DistributionWorker.perform_async(reblog.id)
    ActivityPub::DistributionWorker.perform_async(reblog.id) unless reblogged_status.local_only?

    if !options[:distribute] && account&.user&.boost_interval?
      QueuedBoost.find_or_create_by!(account_id: account.id, status_id: reblogged_status.id) if account&.user&.boost_interval?
    elsif !options[:nodistribute]
      return reblog unless options[:distribute] || new_reblog

      DistributionWorker.perform_async(reblog.id)

      unless reblogged_status.local_only?
        ActivityPub::DistributionWorker.perform_async(reblog.id)
      end

      curate_status(reblogged_status)

      create_notification(reblog) unless options[:skip_notify]
      bump_potential_friendship(account, reblog)
    end

    reblog
  end

  private

  def create_notification(reblog)
    reblogged_status = reblog.reblog

    if reblogged_status.account.local?
      LocalNotificationWorker.perform_async(reblogged_status.account_id, reblog.id, reblog.class.name)
    elsif !reblogged_status.account.following?(reblog.account)
      ActivityPub::DeliveryWorker.perform_async(build_json(reblog), reblog.account_id, reblogged_status.account.inbox_url)
    end
  end

  def bump_potential_friendship(account, reblog)
    ActivityTracker.increment('activity:interactions')
    return if account.following?(reblog.reblog.account_id)
    PotentialFriendshipTracker.record(account.id, reblog.reblog.account_id, :reblog)
  end

  def build_json(reblog)
    Oj.dump(serialize_payload(reblog, ActivityPub::ActivitySerializer, signer: reblog.account))
  end

  def curate_status(status)
    return if status.curated || !status.distributable? || (status.reply? && status.in_reply_to_account_id != status.account_id)
    status.update(curated: true)
    FanOutOnWriteService.new.call(status)
  end
end
