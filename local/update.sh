#!/bin/sh

cd `dirname $0`

cp /etc/nginx/sites-available/vulpine.club nginx/
cp /etc/nginx/ssl-include.conf nginx/
cp /etc/nginx/vulpine-headers-include.conf nginx/
cp /etc/logrotate.d/nginx nginx/logrotate-nginx

cp /etc/cron.daily/certbot cron.daily/
cp /etc/cron.daily/mastodon cron.daily/

cp /etc/cron.hourly/mastodon cron.hourly/

mkdir -p ../public/assets/
curl https://vulpine.club/500 > ../public/assets/500.html
