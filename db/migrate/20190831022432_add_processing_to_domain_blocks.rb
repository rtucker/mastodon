class AddProcessingToDomainBlocks < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :domain_blocks, :processing, :boolean, null: false, default: true }
  end
end
