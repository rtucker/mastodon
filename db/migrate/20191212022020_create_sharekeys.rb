class CreateSharekeys < ActiveRecord::Migration[5.2]
  def up
    create_table :sharekeys do |t|
      t.references :status, foreign_key: true, index: {unique: true}
      t.string :key
    end

    safety_assured do
      execute 'INSERT INTO sharekeys (status_id, key) SELECT id, sharekey FROM statuses WHERE local AND sharekey IS NOT NULL'
      remove_column :statuses, :sharekey
    end
  end

  def down
    add_column :statuses, :sharekey, :string
    execute 'UPDATE statuses SET sharekey = s.key FROM (SELECT status_id, key FROM sharekeys) AS s WHERE statuses.id = s.id'
    drop_table :sharekeys
  end
end
