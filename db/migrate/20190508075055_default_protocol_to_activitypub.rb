class DefaultProtocolToActivityPub < ActiveRecord::Migration[5.2]
  def change
    change_column_default :accounts, :protocol, 1
  end
end
