class MigrateBackToFts < ActiveRecord::Migration[5.2]
  def up
    if table_exists? :normalized_statuses
      remove_index :normalized_statuses, name: 'index_statuses_on_normalized_text_trgm'
      drop_table :normalized_statuses
    end

    safety_assured do
      execute <<-SQL.squish
        DROP FUNCTION IF EXISTS public.f_normalize;
        DROP FUNCTION IF EXISTS public.f_unaccent;

        CREATE OR REPLACE FUNCTION public.f_strip_mentions(text)
          RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
          $func$
            SELECT regexp_replace(
              regexp_replace($1, '</?span>', '', 'g'),
              '>@[^[:space:]]+<', '><', 'g'
            )
          $func$;

        CREATE OR REPLACE AGGREGATE tsquery_union(tsquery) (
          SFUNC = tsquery_or,
          STYPE = tsquery,
          PARALLEL = SAFE
        );

        CREATE TEXT SEARCH CONFIGURATION fedi ( COPY = simple );

        ALTER TEXT SEARCH CONFIGURATION fedi
          ALTER MAPPING FOR hword, hword_part, word
            WITH unaccent, simple;

        ALTER TABLE statuses
          ADD COLUMN tsv tsvector
          GENERATED ALWAYS AS (
            to_tsvector('fedi', f_strip_mentions(spoiler_text || ' ' || text))
          ) STORED;
      SQL
    end
  end
end
