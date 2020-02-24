class RemoveCuratedFlagOnNonDistributableStatuses < ActiveRecord::Migration[5.2]
  def up
    Status.where(visibility: [:private, :limited, :direct], curated: true).in_batches.update_all(curated: false)
  end

  def down
    false
  end
end
