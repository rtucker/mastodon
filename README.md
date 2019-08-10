# Monsterfork

> *[Monsterpit](https://monsterpit.net/about/more) is a community of creatures and critters* /
> *For those who love monsters to be monsters they love.* /
> *Whether fur, scale, or skin; whether plural or ‘kin–* /
> *If you don’t feel quite human, come!* /
> *You’ll fit right on in.*

Monsterfork is a... well... fork of [Glitch-Soc](https://glitch-soc.github.io) used on [Monsterpit](https://monsterpit.net/about).  It focuses on adding a *monstrous* number of community features with wild abandon along with improved accessibility, better moderation tools, and more user privacy options.

## Non-exhaustive feature list

### Identity
- [Signatures](https://monsterpit.blog/monsterpit-bangtags/i-am)
- Account switching

### Advanced
- [Bangtag macros](https://monsterpit.blog/monsterpit-bangtags)

### Privacy
- [Sharekeys](https://monsterpit.blog/monsterpit-bangtags/sharekey-new)
- Self-destructing posts
- Optional public profile pages and ActivityPub outbox
- Option to limit the length of time posts are avaiable

### Accessibility
- Media descriptions shown as captions in UI by default
- High-contrast visibility icons by default
- UI element size and spacing options

### Boundries
- Respect "don't `@` me"
- All threads can be muted

### Anxiety reduction
- No metrics in the UI
- Additional post and thread filtering options
- Granular visibility options
- [Community-curated world timeline](https://monsterpit.blog/monsterpit-creature-comforts/world-timeline)

### Publishing
- Delayed posts
- Queued boosts
- Formatting (BBdown, BBcode, Markdown, HTML, console, plain)
- Arbitary attachments

### Tagging
- Scoped tags (`#monsters.kobolds`, `#local.minotaur.den` `#self.drafts`)
- Unlisted tags (`#.hidden`)
- Retroactive tagging (`#!parent:tag:art`)
- Out-of-body tags
- Glitch-Soc bookmarks as a tag (`#self.bookmarks`)

### Imports
- Users can add their own custom emoji
- Emoji can be imported from other posts (`#!parent:emoji`) or threads (`#!thread:emoji`)
- Post importing from other ActivityPub software (currently text only)

### Moderation
- Additional policies (force unlisted, force sensitive, reject unknown)
- Moderator bangtags (`#!admin:silence`, `#!admin:suspend`, `#!admin:reset`, ...)
- New admin transparancy log system, posted under a tag
- Domain policy comments and list (`https://instance.site/policies`)

### Safety
- Graylist-based federation by default
- Domain suspensions include subdomains
- Can block malicious servers by ActivityPub object propreties
- Tools to block resource requests (see `/dist`)
