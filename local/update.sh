#!/bin/sh

cd `dirname $0`

cp /etc/nginx/sites-available/vulpine.club nginx/vulpine.club
cp /etc/nginx/ssl-include.conf nginx/ssl-include.conf

cp /etc/cron.daily/certbot cron.daily/certbot
cp /etc/cron.daily/mastodon cron.daily/mastodon

cp /etc/cron.hourly/mastodon cron.hourly/mastodon

