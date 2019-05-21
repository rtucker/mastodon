class AddImportedToStatuses < ActiveRecord::Migration[5.2]
  def change
    add_column :statuses, :imported, :boolean
  end
end
