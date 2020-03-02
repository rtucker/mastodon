class AddMoreIndexes < ActiveRecord::Migration[5.2]
  def up
    safety_assured do
      add_index :domain_blocks, :severity
      add_index :custom_filters, :phrase, unique: true
    end
  end
end
