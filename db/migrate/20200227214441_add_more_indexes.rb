class AddMoreIndexes < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_index :domain_blocks, :severity
      add_index :custom_filters, [:account_id, :phrase], unique: true
    end
  end
end
