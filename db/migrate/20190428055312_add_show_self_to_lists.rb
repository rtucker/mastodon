class AddShowSelfToLists < ActiveRecord::Migration[5.2]
  def change
    safety_assured { add_column :lists, :show_self, :boolean, default: false, null: false }
  end
end
