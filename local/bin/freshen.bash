#!/usr/bin/env bash

set -e

if [ "$(basename $(pwd))" != "mastodon" -o ! -d ".git" ]; then
    echo "are you in the right directory"
    exit 1
fi

git fetch --all
git checkout master-glitchsoc
git rebase glitchsoc/master
git push
git checkout master
git log master..master-glitchsoc
