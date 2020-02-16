class RemoveUnusedIndexes202002 < ActiveRecord::Migration[5.2]
  def change
    if index_exists? :statuses, name: 'index_statuses_on_account_id_and_id_and_visibility_not_hidden'
      remove_index :statuses, name: 'index_statuses_on_account_id_and_id_and_visibility_not_hidden'
    end
  end
end
