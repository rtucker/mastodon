class AddSharekeyToStatus < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :sharekey, :string
  end
end
