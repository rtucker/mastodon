class MakePrivateTagsUnlisted < ActiveRecord::Migration[5.2]
  def up
    Tag.where(private: true).in_batches.update_all(unlisted: true)
  end
end
