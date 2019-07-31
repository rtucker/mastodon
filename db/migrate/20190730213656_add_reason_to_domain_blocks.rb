class AddReasonToDomainBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :domain_blocks, :reason, :text
  end
end
