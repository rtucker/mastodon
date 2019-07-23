class CreateDestructingStatuses < ActiveRecord::Migration[5.2]
  def change
    create_table :destructing_statuses do |t|
      t.references :status, foreign_key: true
      t.datetime :delete_after
    end
    add_index :destructing_statuses, :delete_after
  end
end
