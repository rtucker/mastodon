class AdultsOnlyToAdultContent < ActiveRecord::Migration[5.2]
  def up
    safety_assured { rename_column :accounts, :adults_only, :adult_content }
  end
  def down
    safety_assured { rename_column :accounts, :adult_content, :adults_only }
  end
end
