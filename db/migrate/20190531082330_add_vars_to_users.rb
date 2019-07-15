class AddVarsToUsers < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :users, :vars, :jsonb, null:false, default: {} }
  end
end
