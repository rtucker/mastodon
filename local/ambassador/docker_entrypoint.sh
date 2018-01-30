#!/bin/sh

echo "Creating ambassador user (UID : ${UID} and GID : ${GID})..."
addgroup -g ${GID} ambassador && adduser -h /ambassador -s /bin/sh -D -G ambassador -u ${UID} ambassador

echo "Updating permissions..."
chown -R ambassador:ambassador /ambassador

echo "Executing process..."
cd /ambassador
exec su-exec ambassador:ambassador /sbin/tini -- "$@"

