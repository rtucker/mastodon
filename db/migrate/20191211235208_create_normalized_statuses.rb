class CreateNormalizedStatuses < ActiveRecord::Migration[5.2]
  def up
    create_table :normalized_statuses do |t|
      t.references :status, foreign_key: true
      t.text :text
    end

    safety_assured do
      remove_index :statuses, name: 'index_statuses_on_normalized_text_trgm'
      execute 'INSERT INTO normalized_statuses (status_id, text) SELECT id, normalized_text FROM statuses'
      remove_column :statuses, :normalized_text
    end
  end

  def down
    safety_assured do
      execute 'UPDATE statuses SET normalized_text = s.text FROM (SELECT status_id, text FROM normalized_statuses) AS s WHERE statuses.id = s.id'
      remove_index :normalized_statuses, name: 'index_statuses_on_normalized_text_trgm'
      drop_table :normalized_statuses
      add_column :statuses, :normalized_text, :text, null: false, default: ''
    end
  end
end
