# frozen_string_literal: true

class StatusFilter
  include FilterHelper
  include Redisable

  attr_reader :status, :account

  def initialize(status, account, preloaded_relations = {})
    @status              = status
    @account             = account
    @preloaded_relations = preloaded_relations
  end

  def filtered?
    return true if status.nil? || blocked_by_policy?
    return false if account.nil? || account.id == status.account_id
    return true if redis.sismember("filtered_statuses:#{account.id}", status.id)

    if filtered_status? || silenced_account?
      redis.sadd("filtered_statuses:#{account.id}", status.id)
      return true
    end

    false
  end

  private

  def account_present?
    !account.nil?
  end

  def filtered_status?
    blocking_account? || blocking_domain? || muting_account? || filtered_reference?
  end

  def filtered_reference?
    # filter muted/blocked
    return true if account.user_hides_replies_of_blocked? && reply_to_blocked?
    return true if account.user_hides_replies_of_muted? && reply_to_muted?
    return true if account.user_hides_replies_of_blocker? && reply_to_blocker?

    # filtered by user?
    if account.user.filters_enabled && !account.user.filter_timelines_only
      if account.user.invert_filters
        return true unless phrase_filtered?(status, account.id, skip_redis: true)
      else
        return true if phrase_filtered?(status, account.id, skip_redis: true)
      end
    end

    # kajiht has no filters if status has no mentions
    return false if status&.mentions.blank?

    # Grab a list of account IDs mentioned in the status.
    mentioned_account_ids = status.mentions.pluck(:account_id)
    mentioned_accounts = Account.where(id: mentioned_account_ids)

    # Don't filter statuses mentioning you.
    return false if mentioned_account_ids.include?(account.id)

    # Filter posts missing media descriptions.
    return true if account.user.filter_undescribed? && status.media_attachments.present? && status.media_attachments.all? { |attachment| attachment.description.blank? }

    return true if account.user_hides_mentions_of_blocked? && mentioned_accounts.where.not(suspended_at: nil).exists?

    return true if mentioned_account_ids.any? do |mentioned_account_id|
      break true if @preloaded_relations[:muting] && account.user_hides_mentions_of_muted? && @preloaded_relations[:muting][mentioned_account_id]
      break true if @preloaded_relations[:blocking] && account.user_hides_mentions_of_blocked? && @preloaded_relations[:blocking][mentioned_account_id]

      if @preloaded_relations[:blocked_by]
        break true if account.user_hides_mentions_of_blocker? && @preloaded_relations[:blocked_by][mentioned_account_id]
      else
        break true if account.user_hides_mentions_of_blocker? && Block.where(account_id: mentioned_account_id, target_account_id: account.id).exists?
      end

      break false unless status.reply? && status.private_visibility? && account.user_hides_mentions_outside_scope?
      @preloaded_relations[:following] && !@preloaded_relations[:following][mentioned_account_id]
    end

    return true if !@preloaded_relations[:muting] && account.user_hides_mentions_of_muted? && account.muting?(mentioned_account_ids)
    return true if !@preloaded_relations[:blocking] && account.user_hides_mentions_of_blocked? && account.blocking?(mentioned_account_ids)
    return false unless status.reply? && status.private_visibility? && account.user_hides_mentions_outside_scope?
    !@preloaded_relations[:following] && (mentioned_account_ids - account.following_ids).any?
  end

  def reply_to_blocked?
    @preloaded_relations[:blocking] ? @preloaded_relations[:blocking][status.in_reply_to_account_id] : account.blocking?(status.in_reply_to_account_id)
  end

  def reply_to_muted?
    @preloaded_relations[:muting] ? @preloaded_relations[:muting][status.in_reply_to_account_id] : account.muting?(status.in_reply_to_account_id)
  end

  def blocking_account?
    @preloaded_relations[:blocking] ? @preloaded_relations[:blocking][status.account_id] : account.blocking?(status.account_id)
  end

  def blocking_domain?
    @preloaded_relations[:domain_blocking_by_domain] ? @preloaded_relations[:domain_blocking_by_domain][status.account_domain] : account.domain_blocking?(status.account_domain)
  end

  def muting_account?
    @preloaded_relations[:muting] ? @preloaded_relations[:muting][status.account_id] : account.muting?(status.account_id)
  end

  def account_following_status_account?
    @preloaded_relations[:following] ? @preloaded_relations[:following][status.account_id] : account&.following?(status.account_id)
  end

  def reply_to_blocker?
    status.in_reply_to_account.present? && status.in_reply_to_account.blocking?(account)
  end

  def silenced_account?
    !account&.silenced? && status_account_silenced? && !account_following_status_account?
  end

  def status_account_silenced?
    status.account.silenced?
  end

  def blocked_by_policy?
    !policy_allows_show?
  end

  def policy_allows_show?
    StatusPolicy.new(account, status, @preloaded_relations).show?
  end
end
