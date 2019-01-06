# frozen_string_literal: true

class StatusFilter
  attr_reader :status, :account

  def initialize(status, account, preloaded_relations = {})
    @status              = status
    @account             = account
    @preloaded_relations = preloaded_relations
  end

  def filtered?
    return false if !account.nil? && account.id == status.account_id
    blocked_by_policy? || (account_present? && filtered_status?) || silenced_account?
  end

  private

  def account_present?
    !account.nil?
  end

  def filtered_status?
    blocking_account? || blocking_domain? || muting_account? || filtered_reference?
  end

  def filtered_reference?
    filtered_reply = reply_to_blocked? || reply_to_muted?

    # I don't think this should happen, but just in case...
    return filtered_reply if status&.mentions.nil?

    # Grab a list of account IDs mentioned in the status.
    mentioned_account_ids = status.mentions.pluck(:account_id)

    # Don't filter statuses mentioning you.
    return false if mentioned_account_ids.include?(account.id)

    # Otherwise, filter replies to someone you've muted or blocked.
    return true if filtered_reply

    # Otherwise, filter the status if it mentions someone in the preloaded muting relation.
    return true if @preloaded_relations[:muting] && mentioned_account_ids.any? do |mentioned_account_id|
      @preloaded_relations[:muting][mentioned_account_id]
    end

    # Otherwise, filter the status if it mentions someone you've muted.
    return true if account.muting?(mentioned_account_ids)

    # Same as above, but for blocks:
    return true if @preloaded_relations[:blocking] && mentioned_account_ids.any? do |mentioned_account_id|
      @preloaded_relations[:blocking][mentioned_account_id]
    end

    account.blocking?(mentioned_account_ids)
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

  def silenced_account?
    !account&.silenced? && status_account_silenced? && !account_following_status_account?
  end

  def status_account_silenced?
    status.account.silenced?
  end

  def account_following_status_account?
    @preloaded_relations[:following] ? @preloaded_relations[:following][status.account_id] : account&.following?(status.account_id)
  end

  def blocked_by_policy?
    !policy_allows_show?
  end

  def policy_allows_show?
    StatusPolicy.new(account, status, @preloaded_relations).show?
  end
end
