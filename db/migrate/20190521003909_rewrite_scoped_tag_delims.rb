class RewriteScopedTagDelims < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def up
    Tag.where("tags.name LIKE '%:%'").find_each do |tag|
      tag.name.gsub!(':', '.')
      tag.save
    end
  end
end
