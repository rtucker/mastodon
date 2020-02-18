class AddDefangedToUsers < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :users, :defanged, :boolean, null: false, default: true }
  end
end
