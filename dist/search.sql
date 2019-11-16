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

-- Create new trigram indexes --
CREATE INDEX CONCURRENTLY IF NOT EXISTS index_statuses_on_text_trgm ON statuses USING GIN (text gin_trgm_ops);
CREATE INDEX CONCURRENTLY IF NOT EXISTS index_statuses_on_spoiler_text_trgm ON statuses USING GIN (spoiler_text gin_trgm_ops);
