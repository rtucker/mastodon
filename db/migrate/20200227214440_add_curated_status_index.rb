class AddCuratedStatusIndex < ActiveRecord::Migration[5.2]
  def up
    safety_assured do
      add_index :statuses, [:id, :account_id], where: 'curated AND (NOT hidden) AND (deleted_at IS NULL)', order: { id: :desc }, name: :index_statuses_curated_20200301
    end
  end
end
