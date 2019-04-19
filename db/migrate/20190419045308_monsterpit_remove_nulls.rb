class MonsterpitRemoveNulls < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      change_column_null :statuses, :curated, false, false
      change_column_default :statuses, :curated, false

      change_column_null :statuses, :network, false, false
      change_column_default :statuses, :network, false

      change_column_null :accounts, :hidden, false, false
      change_column_default :accounts, :hidden, false

      change_column_null :accounts, :vars, false, {}
      change_column_default :accounts, :vars, {}
    end
  end
end
