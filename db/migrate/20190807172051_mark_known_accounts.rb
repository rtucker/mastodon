class MarkKnownAccounts < ActiveRecord::Migration[5.2]
  def up
    Rails.logger.info("Marking known accounts:")
    known_accounts = local_accounts | packmates | boosted_authors | faved_authors
    Rails.logger.info("  Updating account flags...")
    Account.where(id: known_accounts).in_batches.update_all(known: true)
  end

  private

  def boosted_authors
    Rails.logger.info("  Gathering boosted accounts...")
    Status.where(id: Status.local.reblogs.reorder(nil).select(:reblog_of_id)).reorder(nil).pluck(:account_id)
  end

  def faved_authors
    Rails.logger.info("  Gathering favourited accounts...")
    Status.where(id: Favourite.select(:status_id)).reorder(nil).pluck(:account_id)
  end

  def local_accounts
    Rails.logger.info("  Gathering local accounts...")
    Account.local.pluck(:id)
  end

  def packmates
    Rails.logger.info("  Gathering packmate accounts...")
    Account.local.flat_map { |account| account.following_ids | account.follower_ids }
  end
end
