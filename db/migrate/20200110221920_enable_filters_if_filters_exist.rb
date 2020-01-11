class EnableFiltersIfFiltersExist < ActiveRecord::Migration[5.2]
  def up
    Account.local.find_each do |account|
      account.user.update!(filters_enabled: !account.custom_filters.enabled.blank?)
    end
  end
end
