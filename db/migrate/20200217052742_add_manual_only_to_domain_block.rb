class AddManualOnlyToDomainBlock < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :domain_blocks, :manual_only, :boolean, default: false, null: false }
  end
end
