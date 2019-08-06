class CreateLinkedUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :linked_users do |t|
      t.references :user, foreign_key: { on_delete: :cascade }
      t.references :target_user, foreign_key: { to_table: 'users', on_delete: :cascade }

      t.timestamps
    end

    add_index :linked_users , [:user_id, :target_user_id], :unique => true
  end
end
