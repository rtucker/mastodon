class CreateDefederatingStatuses < ActiveRecord::Migration[5.2]
  def change
    create_table :defederating_statuses do |t|
      t.references :status, foreign_key: true
      t.datetime :defederate_after
    end
    safety_assured { add_index :defederating_statuses, :defederate_after }
  end
end
