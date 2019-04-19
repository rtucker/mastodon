class AddVarsToAccounts < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :vars, :jsonb
  end
end
