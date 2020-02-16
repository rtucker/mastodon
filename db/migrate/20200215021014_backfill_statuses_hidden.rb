class BackfillStatusesHidden < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    Rails.logger.info("Setting all statuses unhidden by default.  This may take a really long time.")
    Status.where.not(hidden: false).in_batches.update_all(hidden: false)
  end
end
