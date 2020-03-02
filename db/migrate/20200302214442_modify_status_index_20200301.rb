class ModifyStatusIndex20200301 < ActiveRecord::Migration[5.2]
  def up
    safety_assured do
      remove_index :statuses, name: :index_statuses_20200301
      remove_index :statuses, name: :index_statuses_curated_20200301
      remove_index :statuses, name: :index_statuses_public_20200301
      remove_index :statuses, name: :index_statuses_local_20200301
      remove_index :statuses, name: :index_statuses_hidden_20200301

      add_index :statuses, [:id, :account_id, :visibility, :created_at, :updated_at], where: 'deleted_at IS NULL', order: { id: :desc }, name: :index_statuses_20200301
      add_index :statuses, [:id, :account_id, :visibility], where: '(curated) OR (curated = TRUE) OR (curated IS TRUE)', order: { id: :desc }, name: :index_statuses_curated_20200301
      add_index :statuses, [:id, :account_id, :visibility], where: '(network) OR (network = TRUE) OR (network IS TRUE)', order: { id: :desc }, name: :index_statuses_network_20200301
      add_index :statuses, [:id, :account_id, :visibility], where: '((local) OR (local = TRUE) OR (uri IS NULL)) AND (deleted_at IS NULL)', order: { id: :desc }, name: :index_statuses_local_20200301
      add_index :statuses, [:id, :account_id, :visibility], where: 'visibility IN (0, 5) OR (visibility = 0) OR (visibility = 5)', order: { id: :desc }, name: :index_statuses_public_20200301
      add_index :statuses, [:id, :account_id, :visibility], where: 'visibility IN (0, 1, 5) OR (visibility = 0) OR (visibility = 1) OR (visibility = 5)', order: { id: :desc }, name: :index_statuses_public_unlisted_20200301
      add_index :statuses, [:id, :account_id, :visibility], where: '(NOT reply) OR (reply = FALSE) OR (reply IS FALSE) OR (in_reply_to_account_id = account_id)', name: :index_statuses_without_replies_20200301
      add_index :statuses, [:id, :account_id, :visibility], where: 'reblog_of_id IS NULL', name: :index_statuses_without_reblogs_20200301
      add_index :statuses, [:id, :account_id, :visibility], where: '(hidden) OR (hidden = FALSE) OR (NOT hidden)', name: :index_statuses_hidden_20200301
    end
  end
end
