class MigrateToNewSearchImpl < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    safety_assured {
      execute 'DROP TRIGGER IF EXISTS tsvectorinsert ON statuses'
      execute 'DROP TRIGGER IF EXISTS tsvectorupdate ON statuses'
      execute 'DROP FUNCTION IF EXISTS tsv_update_trigger'
      execute 'DROP INDEX IF EXISTS tsv_idx'
      execute 'ALTER TABLE statuses DROP COLUMN IF EXISTS tsv'
      execute 'DROP INDEX IF EXISTS index_statuses_on_text_trgm'
      execute 'DROP INDEX IF EXISTS index_statuses_on_spoiler_text_trgm'
      execute <<-SQL.squish
        CREATE OR REPLACE FUNCTION public.f_normalize(text)
          RETURNS text LANGUAGE sql PARALLEL SAFE STRICT AS
            $func$
              SELECT REGEXP_REPLACE(LOWER(unaccent($1)), '"(.*)"', '\\\\y\\1\\\\y')
            $func$
      SQL
      execute 'CREATE INDEX CONCURRENTLY IF NOT EXISTS index_statuses_on_normalized_text_trgm ON statuses USING GIN (normalized_text gin_trgm_ops)'
    }
  end

  def down
    #raise ActiveRecord::IrreversibleMigration
    true
  end
end
