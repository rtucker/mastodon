var mastodon = require('mastodon');
var pg = require('pg');

var DB_USER = process.env.DB_USER || 'ambassador';
var DB_NAME = process.env.DB_NAME || 'mastodon_production';
var DB_PASSWORD = process.env.DB_PASSWORD || '';
var DB_HOST = process.env.DB_HOST || '/var/run/postgresql';
var AMBASSADOR_TOKEN = process.env.AMBASSADOR_TOKEN;
var INSTANCE_HOST = process.env.INSTANCE_HOST;
var BOOSTS_PER_CYCLE = process.env.BOOSTS_PER_CYCLE || 2;
var THRESHOLD_INTERVAL_DAYS = process.env.THRESHOLD_INTERVAL_DAYS || 30;
var BOOST_MAX_DAYS = process.env.BOOST_MAX_DAYS || 5;

var config = {
  user: process.env.DB_USER || 'ambassador',
  database: process.env.DB_NAME || 'mastodon_production',
  password: process.env.DB_PASSWORD || '',
  host: process.env.DB_HOST || '/var/run/postgresql',
  port: 5432, //env var: PGPORT
  max: 2, // max number of clients in the pool
  idleTimeoutMillis: 30000 // how long a client is allowed to remain idle before being closed
};

// Define our threshold (average faves over the past x days)
var thresh_query = `SELECT ceil(avg(favourites_count)) AS threshold
  FROM public_toots
  WHERE
    favourites_count > 1
    AND created_at > NOW() - INTERVAL '` + THRESHOLD_INTERVAL_DAYS + ` days'`

// Find all toots we haven't boosted yet, but ought to
var query = `SELECT id, created_at
  FROM public_toots
  WHERE
    favourites_count >= (` + thresh_query + `)
    AND NOT EXISTS (
      SELECT 1
      FROM public_toots AS pt2
      WHERE
        pt2.reblog_of_id = public_toots.id
        AND pt2.account_id = $1
    )
    AND created_at > NOW() - INTERVAL '` + BOOST_MAX_DAYS + ` days'
  ORDER BY created_at
  LIMIT $2`

console.dir('STARTING AMBASSADOR');
console.log('\tDB_USER:', DB_USER);
console.log('\tDB_NAME:', DB_NAME);
console.log('\tDB_PASSWORD:', DB_PASSWORD.split('').map(function() { return "*" }).join(''));
console.log('\tDB_HOST:', DB_HOST);
console.log('\tAMBASSADOR_TOKEN:', AMBASSADOR_TOKEN);
console.log('\tINSTANCE_HOST:', INSTANCE_HOST);
console.log('\tBOOSTS_PER_CYCLE:', BOOSTS_PER_CYCLE);
console.log('\tTHRESHOLD_INTERVAL_DAYS:', THRESHOLD_INTERVAL_DAYS);
console.log('\tBOOST_MAX_DAYS:', BOOST_MAX_DAYS);

var client = new pg.Client(config);

function cycle() {
  console.log('Cycle beginning');
  client.connect(function (err) {
    if (err) {
      console.error('error connecting to client');
      return console.dir(err);
    }

    client.query(thresh_query, [], function (err, result) {
      if(err) {
        console.error('error running threshold query');
        throw err;
      }

      console.log('Current threshold: ' + result.rows[0].threshold);
    });

    whoami(function (account_id) {
      client.query(query, [account_id, BOOSTS_PER_CYCLE], function (err, result) {
        if(err) {
          console.error('error running toot query');
          throw err;
        }

        client.end(function (err) {
          if (err) {
            console.error('error disconnecting from client');
            throw err;
          }
        });

        boost(result.rows);
      });
    });
  });
}

var M = new mastodon({
  access_token: AMBASSADOR_TOKEN,
  api_url: INSTANCE_HOST + '/api/v1'
});

function whoami(f) {
  M.get('/accounts/verify_credentials', function(err, result) {
    if (err) {
      console.error('error getting current user id');
      throw err;
    }
    console.log('Authenticated as ' + result.id + ' (' + result.display_name + ')');
    return f(result.id);
  })
}

function boost(rows) {
  rows.forEach(function(row) {
    M.post('/statuses/' + row.id + '/reblog', function(err, result) {
      if (err) {
        if (err.message === 'Validation failed: Reblog of status already exists') {
          return console.log('Warning: tried to boost #' + row.id + ' but it had already been boosted by this account.');
        }

        return console.log(err);
      }
      console.log('boosted status #' + row.id);
    });
  })
}

cycle();
// Run every 15 minutes
setInterval(cycle, 1000 * 60 * 15);
