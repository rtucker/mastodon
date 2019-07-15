class MoveAccountVarsToUsers < ActiveRecord::Migration[5.2]
  def up
    Account.local.find_each { |a| a.user.vars = a.vars; a.user.save }
  end
end
