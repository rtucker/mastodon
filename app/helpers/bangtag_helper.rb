module BangtagHelper
  POLICIES = %w(silence unsilence suspend unsuspend force_unlisted allow_public force_sensitive allow_nonsensitive reset)
  EXCLUDED_DOMAINS = %w(tailma.ws monsterpit.net monsterpit.cloud monsterpit.gallery monsterpit.blog)

  def account_policy(username, domain = nil, policy)
    return if policy.blank?
    policy = policy.to_s
    return false unless policy.in?(POLICIES)

    username, domain = username.split('@')[1..2] if username.start_with?('@')
    domain.downcase! unless domain.nil?

    acct = Account.find_by(username: username, domain: domain)
    return false if acct.nil?

    if policy == 'reset'
      Admin::ActionLog.create(account: @account, action: unsuspend, target: acct)
      Admin::ActionLog.create(account: @account, action: unsilence, target: acct)
      Admin::ActionLog.create(account: @account, action: allow_public, target: acct)
      Admin::ActionLog.create(account: @account, action: allow_nonsensitive, target: acct)
    else
      Admin::ActionLog.create(account: @account, action: policy, target: acct)
    end

    case policy
    when 'silence'
      acct.silence!
    when 'unsilence'
      acct.unsilence!
    when 'suspend'
      SuspendAccountService.new.call(acct, include_user: true)
      return true
    when 'unsuspend'
      acct.unsuspend!
    when 'force_unlisted'
      acct.force_unlisted
    when 'allow_public'
      acct.allow_public!
    when 'force_sensitive'
      acct.force_sensitive!
    when 'allow_nonsensitive'
      acct.allow_nonsensitive!
    when 'reset'
      acct.unsuspend!
      acct.unsilence!
      acct.allow_public!
      acct.allow_nonsensitive!
    end

    acct.save

    true
  end

  def domain_exists(domain)
    begin
      code = Request.new(:head, "https://#{domain}").perform(&:code)
    rescue
      return false
    end
    return false if [404, 410].include?(code)
    true
  end

  def domain_policy(domain, policy, force_sensitive = false, reject_media = false, reject_reports = false)
    return if policy.blank?
    policy = policy.to_s
    return false unless policy.in?(POLICIES)
    return false unless domain.match?(/\A[\w\-]+\.[\w\-]+(?:\.[\w\-]+)*\Z/)

    domain.downcase!

    return false if domain.in?(EXCLUDED_DOMAINS)

    if policy == 'force_sensitive'
      policy = 'noop'
      force_sensitive = true
    end

    if policy.in? %w(silence suspend force_unlisted)
      return false unless domain_exists(domain)

      domain_block = DomainBlock.find_or_create_by(domain: domain)
      domain_block.severity = policy
      domain_block.force_sensitive = force_sensitive
      domain_block.reject_media = reject_media
      domain_block.reject_reports = reject_reports
      domain_block.save

      Admin::ActionLog.create(account: @account, action: :create, target: domain_block)
      BlockDomainService.new.call(domain_block)
    else
      domain_block = DomainBlock.find_by(domain: domain)
      return false if domain_block.nil?

      Admin::ActionLog.create(account: @account, action: :destroy, target: domain_block)
      UnblockDomainService.new.call(domain_block)
    end

    true
  end
end