class CreateBookmarkTags < ActiveRecord::Migration[5.2]
  def up
    %w(self.bookmarks .self.bookmarks).each { |name| Tag.find_or_create_by(name: name) }
  end
end
