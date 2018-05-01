#!/usr/bin/env python3
#
# Automatically enforces a rate limit on new account creation.  If more than
# MAX_PER_HOUR accounts have been created in the last hour, shut down new
# registrations.
#
# Change INSTANCE_URL and optionally MAX_PER_HOUR
# Run from a cron job like:
#
#   */5 * * * * (cd /home/rtucker/dev/mastodon/local/bin ; python3 floodgate.py)

INSTANCE_URL="https://vulpine.club/"
MAX_PER_HOUR=3

LOG_FILENAME="/var/tmp/floodgate.dat"
RAILS_CMD="/usr/local/bin/docker-compose run --rm web rails"

import requests
import subprocess
import time

def get_count(instance):
    """Returns the current user count for a given instance"""
    r = requests.get(instance + '/api/v1/instance').json()
    return r.get('stats', {}).get('user_count', None)

def store_value(t, v):
    """Stores a value in the log with a given timestamp"""
    with open(LOG_FILENAME, 'a') as fp:
        fp.write("{} {}\n".format(t, v))

def read_values():
    """Reads values from the log and yields (time, value) tuples"""
    try:
        with open(LOG_FILENAME, 'r') as fp:
            for l in fp:
                t, v = l.split(' ')
                yield (int(t), int(v))
    except FileNotFoundError:
        raise StopIteration

def get_value(age=0):
    """Given an age in seconds, returns the newest value which is older than
       that age (or the oldest value, if too old)"""
    prev_t = 0
    prev_v = 0

    thresh = int(time.time() - age)

    for t, v in read_values():
        if prev_t == 0 or (t > prev_t and t < thresh):
            prev_t = t
            prev_v = v

    return (prev_t, prev_v)

def set_registration(v):
    """Enables or disables registrations."""
    cmd = RAILS_CMD.split(' ')

    if v:
        cmd += ['mastodon:settings:open_registrations']
    else:
        cmd += ['mastodon:settings:close_registrations']

    subprocess.call(cmd)

def main():
    runtime = int(time.time())
    user_count = get_count(INSTANCE_URL)

    latest_t, latest_v = get_value()
    hour_ago_t, hour_ago_v = get_value(3600)

    if user_count != latest_v:
        store_value(runtime, user_count)

    open_reg = user_count <= (hour_ago_v + MAX_PER_HOUR)

    print("Current:  {} users".format(user_count))
    print("Historic: {} users as of {} sec ago".format(hour_ago_v, runtime - hour_ago_t))
    print("Open reg: {} (1-hour delta: {})".format(open_reg, user_count - hour_ago_v))

    set_registration(open_reg)

if __name__ == '__main__':
    main()
