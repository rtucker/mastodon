module BlocklistHelper
  FEDIVERSE_SPACE_URLS = ["https://fediverse.network/mastodon?build=gab"]
  VULPINE_CLUB_URL = "https://raw.githubusercontent.com/vulpineclub/vulpineclub.github.io/master/_data/blocks.yml"

  def merged_blocklist
    # ordered by preference
    # prefer vulpine b/c they have easy-to-parse reason text
    blocklist = vulpine_club_blocks | fediverse_space_blocks
    blocklist.uniq { |entry| entry[:domain] }
  end

  def domain_map(domains, reason)
    domains.map! do |domain|
      {domain: domain, severity: :suspend, reason: reason}
    end
  end

  def vulpine_club_blocks
    body = Request.new(:get, VULPINE_CLUB_URL).perform do |response|
      response.code != 200 ? nil : response.body_with_limit(66.kilobytes)
    end

    return [] unless body.present?

    yaml = YAML::load(body)
    yaml.map! do |entry|
      domain = entry['domain']
      next if domain.blank?
      severity = entry['severity'].split('/')
      reject_media = 'nomedia'.in?(severity)
      severity = (severity[0].nil? || severity[0] == 'nomedia') ? 'noop' : severity[0]

      reason = "Imported from <https://vulpine.club>: \"#{entry['reason']}\"#{entry['link'].present? ? " (#{entry['link']})" : ''}".rstrip
      {domain: domain, severity: severity.to_sym, reject_media: reject_media, reason: reason}
    end
  end

  # shamelessly adapted from @zac@computerfox.xyz's `silence` tool
  # <https://github.com/theZacAttacks/silence/blob/master/silence>
  # which you'll find useful if you're a non-monsterfork mastoadmin
  def fediverse_space_fetch_domains(url)
    body = Request.new(:get, url).perform do |response|
      response.code != 200 ? nil : response.body_with_limit(66.kilobytes)
    end

    return [] unless body.present?

    document = Nokogiri::HTML(body)
    document.css('table.table-condensed td a').collect { |link| link.content.strip }
  end

  def fediverse_space_blocks
    domains = FEDIVERSE_SPACE_URLS.flat_map { |url| fediverse_space_fetch_domains(url) }
    domains.uniq!

    domain_map(domains, "Imported from <https://fediverse.space>.")
  end
end
