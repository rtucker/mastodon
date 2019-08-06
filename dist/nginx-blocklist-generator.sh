#!/bin/sh

if ! [ $(id -u) = 0 ]; then
  echo 'This utility requires root privileges.' >&2
  exit 1
fi

if [ -z "$NGINX_BLOCKED_DOMAINS_CONF" ]
  NGINX_BLOCKED_DOMAINS_CONF='/etc/nginx/conf.d/blocked-domains.conf'
fi

if [ -z "$BLOCKED_DOMAINS_FILE" ]; then
  BLOCKED_DOMAINS_FILE='/var/lib/mastodon/conf/blocklist.txt'
fi

# does the domain blocks file exist?
if [ ! -f "$BLOCKED_DOMAINS_FILE" ]; then
  echo "No blocked domains file exists at '$BLOCKED_DOMAINS_FILE'." >&2
  exit 1
fi

# does the domain block map file for nginx exist?
if [ ! -f "$NGINX_BLOCKED_DOMAINS_CONF" ]; then
  # try to create the parent directory if needed
  parent_dir=$(dirname "$NGINX_BLOCKED_DOMAINS_CONF")
  mkdir -p "$parent_dir"

  # then try to create the file if needed
  if ! touch -a "$f"
    echo "Can't create '$NGINX_BLOCKED_DOMAINS_CONF'." >&2
    echo 'Check $NGINX_BLOCKED_DOMAINS_CONF variable or directory permissions.' >&2
    exit 1
  fi
fi

generate_map () {
  echo '# to use, include the following in the "server" block of your nginx conf'
  echo '# for mastodon **before any "location" blocks**:'
  echo '#'
  echo '# if ($blocked_domain = "1") { return 444; }'
  echo
  echo 'map $http_user_agent $blocked_domain {'
  echo '  default 0;'
  awk '/^[[:word:]]\.[[:word:]][[:word:].]*$/ { gsub("\\.", "\\.", $1); print "  \"~*(?:\\b)"$1"(?:\\b)\" 1;" }' "$BLOCKED_DOMAINS_FILE"
  echo '}'
}

generate_map > "$NGINX_BLOCKED_DOMAINS_CONF"
