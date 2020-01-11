class AddVisibilityCompatToggle < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      add_column :users, :monsterfork_api, :smallint, null: false, default: 2
    end
  end
end
