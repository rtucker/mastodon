#  Mastodon Glitch Edition (Vulpine Club Remix)  #

[![Build Status](https://travis-ci.org/vulpineclub/mastodon.svg?branch=master)](https://travis-ci.org/vulpineclub/mastodon)

## Glitch Edition README ##

So here's the deal: we all work on this code, and then it runs on dev.glitch.social and anyone who uses that does so absolutely at their own risk. can you dig it?

- You can view documentation for this project at [glitch-soc.github.io/docs/](https://glitch-soc.github.io/docs/).
- And contributing guidelines are available [here](CONTRIBUTING.md) and [here](https://glitch-soc.github.io/docs/contributing/).

## Vulpine Club Remix README ##

This is what's running on https://vulpine.club/, more or less. No warranties, it could destroy everything. 

This is fork of https://github.com/glitch-soc/mastodon (hereafter referred to as "glitchsoc"), which is itself a fork of https://github.com/tootsuite/mastodon ("tootsuite").

### Local features ###

See: [diff of glitch-soc/mastodon:master and vulpineclub/mastodon:master](https://github.com/glitch-soc/mastodon/compare/master...vulpineclub:master)

Highlights:

- Foxes occur whereever possible
- Docker-centered deployment process
- Native IPv6 for all external-facing interfaces

### Branches ###

- `master`: regular merges from glitchsoc/master, hotfixes and features from tootsuite, local modifications and experimental crap
- `staging`: pre-production smoke tests, where I make sure it runs and looks okay and has basic functionality in a Vagrant-encrusted VM
- `production`: this is what is actually deployed on vulpine.club

These branches are automatically built on Docker Hub at [vulpineclub/mastodon](https://hub.docker.com/r/vulpineclub/mastodon/).
