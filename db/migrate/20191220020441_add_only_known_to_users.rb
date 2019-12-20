class AddOnlyKnownToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :only_known, :boolean
  end
end
