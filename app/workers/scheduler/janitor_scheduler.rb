# frozen_string_literal: true

class Scheduler::JanitorScheduler
  include Sidekiq::Worker
  include BlocklistHelper
  include ModerationHelper
  include ServiceAccountHelper
  include Redisable

  MIN_POSTS = 6

  sidekiq_options unique: :until_executed

  def perform
    @account = find_service_account('janitor')
    return if @account.nil?

    @exclude_ids = excluded_account_ids
    @exclude_domains = excluded_domains
    @exclude_markov = excluded_accounts_from_env('MARKOV')

    prune_deleted_accounts!
    suspend_abandoned_accounts!
    silence_markov!
    import_blocklists!
    export_suspensions!
    export_activityrelay_config!
  end

  private

  def prune_deleted_accounts!
    Account.local.where.not(suspended_at: nil).destroy_all
  end

  def suspend_abandoned_accounts!
    reason = 'Appears to be abandoned. Freeing up the username for someone else.'
    abandoned_accounts.find_each do |account|
      account_policy(account.username, nil, :suspend, reason)
    end
  end

  def silence_markov!
    reason = 'Appears to be a markov bot.'
    markov_accounts.find_each do |markov|
      account_policy(markov.username, markov.domain, :silence, reason)
    end
  end

  def import_blocklists!
    blocks = merged_blocklist.reject { |entry| entry[:domain].in?(@exclude_domains) }
    blocks.each do |entry|
      next unless domain_exists?(entry[:domain])

      block = DomainBlock.create!(entry)
      Admin::ActionLog.create(account: @account, action: :create, target: block)
      user_friendly_action_log(@account, :create, block)
    end
  end

  def export_suspensions!
    outfile = ENV.fetch('JANITOR_BLOCKLIST_OUTPUT', '')
    return if outfile.blank?
    return unless File.file?(outfile)

    File.open(outfile, 'w:UTF-8') do |file|
      file.puts(DomainBlock.suspend.pluck(:domain))
    end
  end

  def export_activityrelay_config!
    outfile = ENV.fetch('ACTIVITYRELAY_OUTPUT', '')
    return if outfile.blank?
    return unless File.file?(outfile)

    File.open(outfile, 'w:UTF-8') do |file|
      formatted_allowlist = allowed_domains.uniq.map { |d| "  - '#{d}'" }
      formatted_blocklist = DomainBlock.suspend.pluck(:domain).map { |d| "  - '#{d}'" }

      file.puts('db: relay.jsonld')
      file.puts("listen: #{ENV.fetch('ACTIVITYRELAY_LISTEN', '127.0.0.1')}")
      file.puts("port: #{ENV.fetch('ACTIVITYRELAY_PORT', '9001')}")
      file.puts("note: \"#{ENV.fetch('ACTIVITYRELAY_NOTE', "#{Setting.site_title} relay")}\"")
      file.puts('ap:')
      file.puts("  host: '#{ENV.fetch('ACTIVITYRELAY_HOST', "relay.#{Rails.configuration.x.local_domain}")}'")
      file.puts('  blocked_instances:')
      file.puts(formatted_blocklist)
      file.puts("  whitelist_enabled: #{ENV.fetch('ACTIVITYRELAY_ALLOWLIST', 'true')}")
      file.puts('  whitelist:')
      file.puts(formatted_allowlist)
    end
  end

  def markov_accounts
    Account.reorder(nil).where(silenced_at: nil).where.not(id: @exclude_markov)
           .where('username LIKE ? OR note ILIKE ?', '%ebooks%', '%markov%')
  end

  def abandoned_accounts
    Account.reorder(nil).where(id: abandoned_account_ids, actor_type: %w(Person Group))
  end

  def abandoned_users
    User.select(:account_id).where(admin: false, moderator: false).where('last_sign_in_at < ?', 1.month.ago)
  end

  def excluded_domains
    existing_policy_domains | allowed_domains
  end

  def allowed_domains
    domains_from_account_ids | excluded_from_env('DOMAINS')
  end

  def abandoned_account_ids
    AccountStat.select(:account_id)
               .where(account_id: abandoned_users)
               .where('statuses_count < ?', MIN_POSTS)
  end

  def excluded_account_ids
    local_account_ids | outgoing_follow_ids | excluded_accounts_from_env('USERNAMES')
  end

  def existing_policy_domains
    DomainBlock.all.pluck(:domain)
  end

  def domains_from_account_ids
    Account.reorder(nil).where(id: @exclude_ids).pluck(:domain).uniq
  end

  def local_account_ids
    Account.local.reorder(nil).pluck(:id)
  end

  def outgoing_follow_ids
    Account.local.reorder(nil).flat_map(&:following_ids)
  end

  def excluded_accounts_from_env(suffix)
    excluded_usernames = ENV.fetch("JANITOR_EXCLUDE_#{suffix.upcase}", '').split
    Account.reorder(nil).where(username: excluded_usernames).pluck(:id).uniq
  end

  def excluded_from_env(suffix)
    ENV.fetch("JANITOR_EXCLUDE_#{suffix.upcase}", '').split.uniq
  end
end
