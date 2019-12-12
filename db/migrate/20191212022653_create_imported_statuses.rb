class CreateImportedStatuses < ActiveRecord::Migration[5.2]
  def up
    create_table :imported_statuses do |t|
      t.references :status, null: false, foreign_key: {on_delete: :cascade}, index: {unique: true}
      t.string :origin, index: {unique: true}
    end

    safety_assured { execute 'INSERT INTO imported_statuses (status_id, origin) SELECT id, origin FROM statuses WHERE imported' }
    safety_assured do
      remove_column :statuses, :imported
      remove_column :statuses, :origin
    end
  end

  def down
    add_column :statuses, :imported, :boolean
    add_column :statuses, :origin, :string, index: { unique: true }
    execute 'UPDATE statuses SET imported = true, origin = s.origin FROM (SELECT status_id, origin FROM imported_statuses) AS s WHERE statuses.id = s.id'
    drop_table :imported_statuses
  end
end
