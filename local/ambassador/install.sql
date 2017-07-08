-- -*- mode: sql; sql-product: postgres -*-

-- Create a login role for ambassador
CREATE USER ambassador;

-- Use this if your deployment uses passwords rather than peer authentication:
-- ALTER ROLE mastodon_ambassador WITH PASSWORD 'something secret, hopefully';
--
-- Note that PostgreSQL supports setting “encrypted” (hashed) passwords,
-- which is a better option if the password must be stored in some configuration
-- management tool.


-- Now, create the view that ambassador actually uses
CREATE VIEW public_toots AS
  SELECT *
    FROM statuses
   WHERE visibility = 0
     AND NOT EXISTS (
         SELECT 1
           FROM blocks
           JOIN accounts ON blocks.target_account_id = accounts.id
            AND blocks.account_id = statuses.account_id
            AND accounts.username = 'Ambassador'
            AND accounts.domain is null)
;

-- Make sure the role doesn't have access to anything undesireable
REVOKE ALL FROM ambassador;

-- Let ambassador select from the view
GRANT SELECT ON public_toots TO ambassador;
