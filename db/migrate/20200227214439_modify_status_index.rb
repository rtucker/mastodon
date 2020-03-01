class ModifyStatusIndex < ActiveRecord::Migration[5.2]
  def up
    remove_index :statuses, name: :index_statuses_20190820
    remove_index :statuses, name: :index_statuses_on_account_id_and_id_and_visibility_not_hidden
    remove_index :statuses, name: :index_statuses_on_account_id_and_id_and_visibility
    remove_index :statuses, name: :index_statuses_local_20190824

    safety_assured do
      add_index :statuses, [:account_id, :id, :visibility, :updated_at], where: '(deleted_at IS NULL) AND (NOT hidden)', order: { id: :desc }, name: :index_statuses_20200301
      add_index :statuses, [:id, :account_id], where: 'network AND (NOT hidden) AND ((local OR (uri IS NULL)) AND (deleted_at IS NULL) AND (visibility IN (0, 5)) AND (reblog_of_id IS NULL) AND ((NOT reply) OR (in_reply_to_account_id = account_id)))', order: { id: :desc }, name: :index_statuses_local_20200301
      add_index :statuses, [:id, :account_id], where: '(NOT hidden) AND ((deleted_at IS NULL) AND (visibility in (0, 1, 5)) AND (reblog_of_id IS NULL) AND ((NOT reply) OR (in_reply_to_account_id = account_id)))', order: { id: :desc }, name: :index_statuses_public_20200301
      add_index :statuses, [:id, :account_id], where: 'hidden', name: :index_statuses_hidden_20200301
    end
  end
end
