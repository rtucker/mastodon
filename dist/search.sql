ALTER TABLE statuses ADD COLUMN tsv tsvector;

CREATE INDEX tsv_idx ON statuses USING gin(tsv);

CREATE FUNCTION tsv_update_trigger() RETURNS trigger AS $$ begin new.tsv := to_tsvector('english', COALESCE(new.spoiler_text, '') || ' ' || new.text); return new; end $$ LANGUAGE plpgsql;

CREATE TRIGGER tsvectorupdate BEFORE UPDATE ON statuses FOR EACH ROW WHEN (old.spoiler_text IS DISTINCT FROM new.spoiler_text OR old.text IS DISTINCT FROM new.text) EXECUTE PROCEDURE tsv_update_trigger();

CREATE TRIGGER tsvectorinsert BEFORE INSERT ON statuses FOR EACH ROW EXECUTE PROCEDURE tsv_update_trigger();

UPDATE statuses SET tsv = to_tsvector('english', COALESCE(spoiler_text, '') || ' ' || text);
