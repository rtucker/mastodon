#!/usr/bin/env bash

set -e

if [ "$(basename $(pwd))" != "mastodon" -o ! -d ".git" ]; then
    echo "are you in the right directory"
    exit 1
fi

tagbase="prod-$(date +%Y%m%d)-"

for i in {1..9}; do
    tagname="${tagbase}0${i}"

    if ! git tag | grep -q $tagname; then
        break
    fi
done

echo "Will tag and deploy: $tagname"
echo -n "Press ctrl-C to stop or wait 3 seconds"
for i in {1..3}; do
    sleep 1
    echo -n "."
done
echo " and we're off!"

git checkout master
git pull
git push

git checkout production
git rebase master
git tag ${tagname}
git push origin ${tagname}
git push origin production
git checkout master
