class SetStatusTextBoolForExistingFilters < ActiveRecord::Migration[5.2]
  def up
    CustomFilter.where(status_text: false).in_batches.update_all(status_text: true)
    CustomFilter.where(spoiler_text: false).in_batches.update_all(spoiler_text: true)
  end
end
