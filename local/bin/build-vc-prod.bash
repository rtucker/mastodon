#!/usr/bin/env bash

if [ -z "${MAX_KBYTES_PER_SEC}" ]; then
    MAX_KBYTES_PER_SEC=625
fi

set -e

if [ -z "$1" ]; then
    echo "usage: $0 prod-yyyymmdd-nn"
    exit 1
fi

tag=$1

builddir=$(mktemp -d /tmp/mastobuild_$tag.XXXXXXXXXX)

git clone -b $tag https://github.com/vulpineclub/mastodon $builddir
pushd $builddir
time docker build --pull \
    --tag vulpineclub/mastodon:production \
    --tag vulpineclub/mastodon:${tag} \
    --build-arg SOURCE_TAG="${tag}" \
    .

TRICKLE=""
if [ -n "${SKIP_TRICKLE}" ]; then
    echo "*** Skipping rate limiting by request"
elif [ -n "$(which trickle)" ]; then
    echo "--- Will rate limit to ${MAX_KBYTES_PER_SEC} KB/s"
    TRICKLE="trickle -u ${MAX_KBYTES_PER_SEC}"
else
    echo "*** No 'trickle' command. Sorry about your upstream. <3"
fi

${TRICKLE} docker push vulpineclub/mastodon:production
${TRICKLE} docker push vulpineclub/mastodon:${tag}
popd

if [ -n "$(which trash)" ]; then
    trash $builddir
else
    echo "Please delete ${builddir}, thanks <3"
fi
