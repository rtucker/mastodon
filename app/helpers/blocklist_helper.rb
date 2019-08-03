module BlocklistHelper
  def merged_blocklist
    # ordered by preference
    # prefer vulpine b/c they have easy-to-parse reason text
    blocklist = vulpine_club_blocks | dialup_express_blocks | ten_forward_blocks
    blocklist.uniq { |entry| entry[:domain] }
  end

  def dialup_express_blocks
    admin_id = Account.find_remote('xenon', 'sleeping.town')&.id
    return [] if admin_id.nil?

    domains = ActiveRecord::Base.connection.select_values("SELECT unnest(regexp_matches(text, '\\m[\\w\\-]+\\.[\\w\-]+(?:\\.[\\w\\-]+)*', 'g')) FROM statuses WHERE account_id = #{admin_id.to_i} AND NOT reply AND created_at >= (NOW() - INTERVAL '2 days') AND tsv @@ to_tsquery('new <-> dialup <-> express <2> block') EXCEPT SELECT domain FROM domain_blocks")

    domains.map! do |domain|
      {domain: domain, severity: :suspend, reason: '(imported from dialup.express)'}
    end
  end

  def ten_forward_blocks
    admin_id = Account.find_remote('guinan', 'tenforward.social')&.id
    return [] if admin_id.nil?

    domains = ActiveRecord::Base.connection.select_values("SELECT unnest(regexp_matches(text, '\\m[\\w\\-]+\\.[\\w\-]+(?:\\.[\\w\\-]+)*', 'g')) FROM statuses WHERE account_id = #{admin_id.to_i} AND NOT reply AND created_at >= (NOW() - INTERVAL '2 days') AND tsv @@ to_tsquery('ten <-> forward <-> moderation <-> announcement') EXCEPT SELECT domain FROM domain_blocks")

    domains.map! do |domain|
      {domain: domain, severity: :suspend, reason: '(imported from ten.forward)'}
    end
  end

  def vulpine_club_blocks
    url = "https://raw.githubusercontent.com/vulpineclub/vulpineclub.github.io/master/_data/blocks.yml"

    body = Request.new(:get, url).perform do |response|
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

      reason = "(imported from vulpine.club) #{entry['reason']}#{entry['link'].present? ? " (#{entry['link']})" : ''}".rstrip
      {domain: domain, severity: severity.to_sym, reject_media: reject_media, reason: reason}
    end
  end
end
