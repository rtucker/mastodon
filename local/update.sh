#!/bin/sh

cd `dirname $0`

cp /etc/nginx/sites-available/vulpine.club nginx/
cp /etc/nginx/ssl-include.conf nginx/
cp /etc/nginx/vulpine-headers-include.conf nginx/

cp /etc/cron.daily/certbot cron.daily/
cp /etc/cron.daily/mastodon cron.daily/

cp /etc/cron.hourly/mastodon cron.hourly/

mkdir -p ../public/assets/
curl http://127.0.0.1:3000/assets/500.html > ../public/assets/500.html
