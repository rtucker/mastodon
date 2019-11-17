-- Run this section on Mastodon DB as Postgres superuser. --
-- sudo -sHu postgres -- psql mastodon_production

CREATE EXTENSION pg_trgm;

-- Run this section on Mastodon DB as Mastodon user. --
-- sudo -sHu mastodon -- psql mastodon_production

-- Drop old FTS implementation --
DROP TRIGGER IF EXISTS tsvectorinsert ON statuses;
DROP TRIGGER IF EXISTS tsvectorupdate ON statuses;
DROP FUNCTION IF EXISTS tsv_update_trigger;
DROP INDEX IF EXISTS tsv_idx;
ALTER TABLE statuses DROP COLUMN IF EXISTS tsv;
DROP INDEX IF EXISTS index_statuses_on_text_trgm;
DROP INDEX IF EXISTS index_statuses_on_spoiler_text_trgm;

-- Create new trigram indexes --
CREATE INDEX CONCURRENTLY IF NOT EXISTS index_statuses_on_normalized_text_trgm ON statuses USING GIN (normalized_text gin_trgm_ops);

-- Compact tables ---
VACUUM ANALYZE;
