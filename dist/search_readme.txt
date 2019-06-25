Since monsterpits fork doesn't support elasticsearch we use the built in postgresql functions for searching.

To install full text search, simply run

psql -d mastodon_production -f search.psql

from the postgres user.

This assumes your database is called mastodon_production and you've moved the search.sql file to your postgres users home directory.