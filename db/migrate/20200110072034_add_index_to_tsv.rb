class AddIndexToTsv < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute 'CREATE INDEX CONCURRENTLY statuses_text_vector_idx ON statuses USING GIN(tsv)'
    end
  end

  def down
    safety_assured do
      execute 'DROP INDEX statuses_text_vector_idx ON statuses'
    end
  end
end
