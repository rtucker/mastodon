# frozen_string_literal: true

class Scheduler::JanitorScheduler
  include Sidekiq::Worker
  include BlocklistHelper
  include ModerationHelper
  include Redisable

  MIN_POSTS = 6

  sidekiq_options unique: :until_executed

  def perform
    @account = janitor_account
    return if @account.nil?

    @exclude_ids = excluded_account_ids
    @exclude_domains = excluded_domains
    @exclude_markov = excluded_accounts_from_env('MARKOV')

    prune_deleted_accounts!
    suspend_abandoned_accounts!
    suspend_spammers!
    silence_markov!
    import_blocklists!
    export_suspensions!
    export_activityrelay_config!
    prune_database! unless redis.exists('janitor:pune_database')
  end

  private

  def prune_deleted_accounts!
    Account.local.where.not(suspended_at: nil).destroy_all
  end

  def prune_database!
    suspended_accounts = Account.where.not(suspended_at: nil).select(:id)
    suspended_domains = DomainBlock.suspend.select(:domain)

    # remove statuses from suspended accounts missed by SuspendStatusService
    # if its sidekiq job crashed
    Status.where(account_id: suspended_accounts).in_batches do |status|
      BatchedRemoveStatusService.new.call(status)
    end

    # prune leaves of threads that lost their context after a suspension
    # keeping these around eats a pretty good amount of storage
    deleted_mentions = Mention.where(account_id: suspended_accounts).select(:status_id)
    Status.remote.where(account_id: deleted_mentions).in_batches do |status|
      BatchedRemoveStatusService.new.call(status)
    end

    # remove mention entries that have no status or account attached to them
    Mention.where(account_id: nil).in_batches.destroy_all
    Mention.where(status_id: nil).in_batches.destroy_all

    # remove media attachments that don't belong to any status
    MediaAttachment.where(status_id: nil).in_batches.destroy_all

    # remove custom emoji from suspended domains missed by SuspendAccountService
    CustomEmoji.where(domain: suspended_domains).in_batches.destroy_all

    # prune empty tags
    Tag.all.find_each { |tag| tag.destroy unless tag.statuses.exists? }

    # remove audit log entries with missing context
    # we already use LOG_USER to avoid that problem
    Admin::ActionLog.where.not(target_id: Account.select(:id)).in_batches.destroy_all
    Admin::ActionLog.where.not(account_id: Account.local.select(:id)).in_batches.destroy_all

    redis.setex('janitor:prune_database', 1.day, 1)
  end

  def suspend_abandoned_accounts!
    reason = "Appears to be abandoned. Freeing up the username for someone else."
    abandoned_accounts.find_each do |account|
      account_policy(account.username, nil, :suspend, reason)
    end
  end

  def suspend_spammers!
    reason = 'Appears to be a spammer account.'
    spammer_accounts.find_each do |spammer|
      account_policy(spammer.username, spammer.domain, :suspend, reason)
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
      DomainBlockWorker.perform_async(block)
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


  def spammer_accounts
    spammer_ids = spammer_account_ids
    Account.reorder(nil).where(id: spammer_ids, suspended_at: nil)
      .where.not(id: @exclude_ids)
  end

  def markov_accounts
    Account.reorder(nil).where(silenced_at: nil).where.not(id: @exclude_markov)
      .where('username LIKE ? OR note ILIKE ?', '%ebooks%', '%markov%')
  end

  def abandoned_accounts
    Account.reorder(nil).where(id: abandoned_account_ids)
  end

  def abandoned_users
    User.select(:account_id).where('last_sign_in_at < ?', 3.months.ago)
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

  def spammer_account_ids
    post_spammer_ids | card_spammer_ids
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
    Account.local.reorder(nil).flat_map { |account| account.following_ids }
  end

  def post_spammer_ids
    Status.with_public_visibility
      .reorder(nil)
      .where('tsv @@ to_tsquery(?)', 'womenarestupid.site & /blog/:*')
      .pluck(:account_id)
  end

  def card_spammer_ids
    PreviewCard.where('url LIKE ? OR title ILIKE ?', '%womenarestupid%', '%womenaredumb%')
      .reorder(nil)
      .flat_map { |card| card.statuses.pluck(:account_id) }
  end


  def excluded_accounts_from_env(suffix)
    excluded_usernames = ENV.fetch("JANITOR_EXCLUDE_#{suffix.upcase}", '').split
    Account.reorder(nil).where(username: excluded_usernames).pluck(:id).uniq
  end

  def excluded_from_env(suffix)
    ENV.fetch("JANITOR_EXCLUDE_#{suffix.upcase}", '').split.uniq
  end
end
