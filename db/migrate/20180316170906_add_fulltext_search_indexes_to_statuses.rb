class AddFulltextSearchIndexesToStatuses < ActiveRecord::Migration[5.1]
  #disable_ddl_transaction!

  def up
    add_column :statuses, :tsv, :tsvector

    safety_assured { execute 'CREATE INDEX tsv_idx ON statuses USING gin(tsv)' }

    ActiveRecord::Base.connection.execute(<<~EOF)
      CREATE FUNCTION tsv_update_trigger() RETURNS trigger AS $$
        BEGIN
          new.tsv := to_tsvector(new.text);
          return new;
        END;
      $$ LANGUAGE plpgsql;
    EOF

    ActiveRecord::Base.connection.execute(<<~EOF)
      CREATE TRIGGER tsvectorupdate
        BEFORE UPDATE ON statuses
        FOR EACH ROW
        WHEN (old.text IS DISTINCT FROM new.text)
        EXECUTE PROCEDURE tsv_update_trigger();
    EOF

    ActiveRecord::Base.connection.execute(<<~EOF)
      CREATE TRIGGER tsvectorinsert
        BEFORE INSERT ON statuses
        FOR EACH ROW
        EXECUTE PROCEDURE tsv_update_trigger();
    EOF

    puts "Populating index (this may take some time)"
    safety_assured { execute 'UPDATE statuses SET tsv = to_tsvector(text)' }
  end

  def down
    safety_assured { execute 'DROP TRIGGER tsvectorinsert' }
    safety_assured { execute 'DROP TRIGGER tsvectorupdate' }
    safety_assured { execute 'DROP FUNCTION tsv_update_trigger' }

    remove_index :statuses, :tsv_idx
    remove_column :statuses, :tsv
  end
end
