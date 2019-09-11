# frozen_string_literal: true

class BlockDomainService < BaseService
  attr_reader :domain_block

  def call(domain_block)
    @domain_block = domain_block
    @affected_status_ids = []

    remove_existing_block!
    process_domain_block!
    invalidate_association_caches!

    @domain_block.update!(processing: false)
  end

  private

  def remove_existing_block!
    UnblockDomainService.new.call(@domain_block, false)
  end

  def process_domain_block!
    clear_media! if domain_block.reject_media? || domain_block.suspend?
    force_accounts_sensitive! if domain_block.force_sensitive?
    mark_unknown_accounts! if domain_block.reject_unknown?
    mark_accounts_manual_only! if domain_block.manual_only?

    if domain_block.force_unlisted?
      force_accounts_unlisted!
    elsif domain_block.silence?
      silence_accounts!
    elsif domain_block.suspend?
      suspend_accounts!
    end
  end

  def invalidate_association_caches!
    # Normally, associated models of a status are immutable (except for accounts)
    # so they are aggressively cached. After updating the media attachments to no
    # longer point to a local file, we need to clear the cache to make those
    # changes appear in the API and UI
    @affected_status_ids.each { |id| Rails.cache.delete_matched("statuses/#{id}-*") }
  end

  def force_accounts_sensitive!
    ApplicationRecord.transaction do
      blocked_domain_accounts.in_batches.update_all(force_sensitive: true)
      blocked_domain_accounts.find_each do |account|
        @affected_status_ids |= account.statuses.where(sensitive: false).pluck(:id)
        account.statuses.where(sensitive: false).in_batches.update_all(sensitive: true)
      end
    end
  end

  def mark_accounts_manual_only!
    blocked_domain_accounts.in_batches.update_all(manual_only: true)
  end

  def mark_unknown_accounts!
    ApplicationRecord.transaction do
      unknown_accounts.in_batches.update_all(known: false)
      unknown_accounts.find_each do |account|
        account.avatar = nil
        account.header = nil
        account.save!
      end
    end
  end

  def force_accounts_unlisted!
    ApplicationRecord.transaction do
      blocked_domain_accounts.in_batches.update_all(force_unlisted: true)
      blocked_domain_accounts.find_each do |account|
        @affected_status_ids |= account.statuses.with_public_visibility.pluck(:id)
        account.statuses.with_public_visibility.in_batches.update_all(visibility: :unlisted)
      end
    end
  end

  def silence_accounts!
    blocked_domain_accounts.without_silenced.in_batches.update_all(silenced_at: @domain_block.created_at)
  end

  def clear_media!

    clear_account_images!
    clear_account_attachments!
    clear_emojos!

  end

  def suspend_accounts!
    blocked_domain_accounts.without_suspended.reorder(nil).find_each do |account|
      SuspendAccountService.new.call(account, reserve_username: true, suspended_at: @domain_block.created_at)
    end
  end

  def clear_account_images!
    blocked_domain_accounts.find_each do |account|
      account.avatar.destroy if account.avatar.exists?
      account.header.destroy if account.header.exists?
      account.save
    end
  end

  def clear_account_attachments!
    media_from_blocked_domain.find_each do |attachment|
      @affected_status_ids << attachment.status_id if attachment.status_id.present?

      attachment.file.destroy if attachment.file.exists?
      attachment.type = :unknown
      attachment.save
    end
  end

  def clear_emojos!
    emojis_from_blocked_domains.destroy_all
  end

  def blocked_domain
    domain_block.domain
  end

  def blocked_domain_accounts
    Account.by_domain_and_subdomains(blocked_domain)
  end

  def media_from_blocked_domain
    MediaAttachment.joins(:account).merge(blocked_domain_accounts).reorder(nil)
  end

  def emojis_from_blocked_domains
    CustomEmoji.by_domain_and_subdomains(blocked_domain)
  end

  def unknown_accounts
    Account.where(id: blocked_domain_accounts.pluck(:id) - known_account_ids).reorder(nil)
  end

  def known_account_ids
    local_accounts | packmates | boosted_authors
  end

  def boosted_authors
    Status.where(id: Status.local.reblogs.reorder(nil).select(:reblog_of_id)).reorder(nil).pluck(:account_id)
  end

  def local_accounts
    Account.local.pluck(:id)
  end

  def packmates
    Account.local.flat_map { |account| account.following_ids | account.follower_ids }
  end
end
