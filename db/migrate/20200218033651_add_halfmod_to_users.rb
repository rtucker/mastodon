class AddHalfmodToUsers < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :users, :halfmod, :boolean, null: false, default: false }
  end
end
