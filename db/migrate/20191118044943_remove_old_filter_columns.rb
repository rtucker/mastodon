class RemoveOldFilterColumns < ActiveRecord::Migration[5.2]
  def up
    CustomFilters.find_each do |filter|
      filter.update!(phrase: "\"#{filter.phrase}\"") if filter.whole_word
    end

    safety_assured {
      remove_column :custom_filters, :no_desc
      remove_column :custom_filters, :desc
      remove_column :custom_filters, :custom_cw
      remove_column :custom_filters, :override_cw
      remove_column :custom_filters, :status_text
      remove_column :custom_filters, :tags
      remove_column :custom_filters, :spoiler
      remove_column :custom_filters, :thread
      remove_column :custom_filters, :media_only
      remove_column :custom_filters, :exclude_media
      remove_column :custom_filters, :whole_word
      remove_column :custom_filters, :irreversible
    }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
