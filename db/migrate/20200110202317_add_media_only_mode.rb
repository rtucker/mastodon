class AddMediaOnlyMode < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :users, :media_only, :boolean, null: false, default: false }
  end
end
