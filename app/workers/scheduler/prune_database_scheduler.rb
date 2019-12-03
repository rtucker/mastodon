# frozen_string_literal: true

class Scheduler::PruneDatabaseScheduler
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed

  def perform
    suspended_accounts = Account.where.not(suspended_at: nil).select(:id)
    suspended_domains = DomainBlock.suspend.select(:domain)

    # remove statuses from suspended accounts missed by SuspendStatusService
    # if its sidekiq job crashed
    Status.where(account_id: suspended_accounts).in_batches do |status|
      BatchedRemoveStatusService.new.call(status)
    end

    # remove mention entries that have no status or account attached to them
    Mention.where(account_id: nil).in_batches.destroy_all
    Mention.where(status_id: nil).in_batches.destroy_all

    # remove media attachments that don't belong to any status
    MediaAttachment.where(status_id: nil).in_batches.destroy_all

    # remove custom emoji from suspended domains missed by SuspendAccountService
    CustomEmoji.where(domain: suspended_domains).in_batches.destroy_all

    # prune empty tags
    Tag.all.find_each { |tag| tag.destroy unless tag.statuses.exists? }

    # remove mainline audit log entries with missing context
    # monsterfork's audit log doesn't have this problem cause we use plaintext
    Admin::ActionLog.where.not(target_id: Account.select(:id)).in_batches.destroy_all
    Admin::ActionLog.where.not(account_id: Account.local.select(:id)).in_batches.destroy_all
  end
end
