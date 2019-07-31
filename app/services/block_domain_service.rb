# frozen_string_literal: true

class BlockDomainService < BaseService
  attr_reader :domain_block

  def call(domain_block)
    @domain_block = domain_block
    remove_existing_block!
    process_domain_block!
  end

  private

  def remove_existing_block!
    UnblockDomainService.new.call(@domain_block, false)
  end

  def process_domain_block!
    clear_media! if domain_block.reject_media?
    force_accounts_sensitive! if domain_block.force_sensitive?

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
      blocked_domain_accounts.reorder(nil).find_each do |account|
        account.statuses.where(sensitive: false).in_batches.update_all(sensitive: true)
      end
    end
    invalidate_association_caches! unless @affected_status_ids.blank?
  end

  def force_accounts_unlisted!
    ApplicationRecord.transaction do
      blocked_domain_accounts.in_batches.update_all(force_unlisted: true)
      blocked_domain_accounts.reorder(nil).find_each do |account|
        account.statuses.with_public_visibility.in_batches.update_all(visibility: :unlisted)
      end
    end
  end

  def silence_accounts!
    blocked_domain_accounts.without_silenced.in_batches.update_all(silenced_at: @domain_block.created_at)
  end

  def clear_media!
    @affected_status_ids = []

    clear_account_images!
    clear_account_attachments!
    clear_emojos!

    invalidate_association_caches!
  end

  def suspend_accounts!
    blocked_domain_accounts.without_suspended.reorder(nil).find_each do |account|
      SuspendAccountService.new.call(account, suspended_at: @domain_block.created_at)
    end
  end

  def clear_account_images!
    blocked_domain_accounts.reorder(nil).find_each do |account|
      account.avatar.destroy if account.avatar.exists?
      account.header.destroy if account.header.exists?
      account.save
    end
  end

  def clear_account_attachments!
    media_from_blocked_domain.reorder(nil).find_each do |attachment|
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
    Account.where(domain: blocked_domain)
  end

  def media_from_blocked_domain
    MediaAttachment.joins(:account).merge(blocked_domain_accounts).reorder(nil)
  end

  def emojis_from_blocked_domains
    CustomEmoji.where(domain: blocked_domain)
  end
end
