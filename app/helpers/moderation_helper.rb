module ModerationHelper
  include LogHelper

  POLICIES = %w(silence unsilence suspend unsuspend force_unlisted mark_known mark_unknown reject_unknown manual_only auto_trust allow_public force_sensitive allow_nonsensitive reset)
  EXCLUDED_DOMAINS = %w(tailma.ws monsterpit.net monsterpit.cloud monsterpit.gallery monsterpit.blog)

  def janitor_account
    account_id = ENV.fetch('JANITOR_USER', '').to_i
    return if account_id.zero?

    Account.find_by(id: account_id)
  end

  def account_policy(username, domain, policy, reason = nil)
    return if policy.blank?

    policy = policy.to_s
    return false unless policy.in?(POLICIES)

    username, domain = username.split('@')[1..2] if username.start_with?('@')
    domain&.downcase!

    acct = Account.find_by(username: username, domain: domain)
    return false if acct.nil?

    if policy == 'reset'
      Admin::ActionLog.create(account: @account, action: 'unsuspend', target: acct)
      user_friendly_action_log(@account, :unsuspend, acct, reason)
    else
      Admin::ActionLog.create(account: @account, action: policy, target: acct)
      user_friendly_action_log(@account, policy.to_sym, acct, reason)
    end

    case policy
    when 'mark_unknown', 'reject_unknown'
      acct.mark_unknown!
    when 'mark_known'
      acct.mark_known!
    when 'manual_only'
      acct.manual_only!
    when 'auto_trust'
      acct.auto_trust!
    when 'silence'
      acct.silence!
    when 'unsilence'
      acct.unsilence!
    when 'suspend'
      SuspendAccountService.new.call(acct, reserve_username: false, reserve_email: false)
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
      acct.mark_known!
    end

    acct.save

    return true unless reason && reason.strip.present?

    AccountModerationNote.create(
      account_id: @account.id,
      target_account_id: acct.id,
      content: reason.strip
    )

    true
  end

  def domain_exists?(domain)
    begin
      code = Request.new(:head, "https://#{domain}").perform(&:code)
    rescue
      return false
    end
    return false if [404, 410].include?(code)

    true
  end

  def domain_policy(domain, policy, reason = nil, force_sensitive: false, reject_unknown: false, reject_media: false, manual_only: false, reject_reports: false)
    return if policy.blank?

    policy = policy.to_s
    return false unless policy.in?(POLICIES)
    return false unless domain.match?(/\A[\w\-]+\.[\w\-]+(?:\.[\w\-]+)*\Z/)

    domain.downcase!

    return false if domain.in?(EXCLUDED_DOMAINS)

    policy = 'noop' if %w(force_sensitive reject_unknown).include?(policy)

    force_sensitive = true if policy == 'force_sensitive'
    reject_unknown = true if policy == 'reject_unknown'
    manual_only = true if policy == 'manual_only'

    if policy.in? %w(silence suspend force_unlisted)
      domain_block = DomainBlock.find_or_create_by(domain: domain)
      domain_block.severity = policy
      domain_block.force_sensitive = force_sensitive
      domain_block.reject_unknown = reject_unknown
      domain_block.manual_only = manual_only
      domain_block.reject_media = reject_media
      domain_block.reject_reports = reject_reports
      domain_block.reason = reason.strip if reason && reason.strip.present?
      domain_block.save

      Admin::ActionLog.create(account: @account, action: :create, target: domain_block)
      user_friendly_action_log(@account, :create, domain_block)
    else
      domain_block = DomainBlock.find_by(domain: domain)
      return false if domain_block.nil?

      Admin::ActionLog.create(account: @account, action: :destroy, target: domain_block)
      user_friendly_action_log(@account, :destroy, domain_block)
      DomainUnblockWorker.perform_async(domain_block.id)
    end

    true
  end
end
