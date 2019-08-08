class AddRejectUnknownToDomainBlocks < ActiveRecord::Migration[5.2]
  def change
    safety_assured {
      add_column :domain_blocks, :reject_unknown, :boolean, null: false, default: false
    }
  end
end
