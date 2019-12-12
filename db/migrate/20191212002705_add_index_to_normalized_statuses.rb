class AddIndexToNormalizedStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute 'CREATE INDEX CONCURRENTLY IF NOT EXISTS index_statuses_on_normalized_text_trgm ON normalized_statuses USING GIN (text gin_trgm_ops)'
    end
  end

  def down
    remove_index :normalized_statuses, name: 'index_statuses_on_normalized_text_trgm'
  end
end
