-- Before running db:migrate, run this on Mastodon DB as Postgres superuser. --
-- sudo -sHu postgres -- psql mastodon_production

CREATE EXTENSION pg_trgm;
CREATE EXTENSION unaccent;
