# frozen_string_literal: true

class Scheduler::JanitorScheduler
  include Sidekiq::Worker
  include BlocklistHelper
  include ModerationHelper

  MIN_POSTS = 6

  sidekiq_options unique: :until_executed, retry: 0

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
  end

  private

  def prune_deleted_accounts!
    Account.local.where.not(suspended_at: nil).destroy_all
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
    existing_policy_domains | domains_from_account_ids | excluded_from_env('DOMAINS')
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
    Account.reorder(nil).where(id: @account_ids).pluck(:domain).uniq
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
    Account.reorder(nil).where(username: excluded_usernames).pluck(:id)
  end

  def excluded_from_env(suffix)
    ENV.fetch("JANITOR_EXCLUDE_#{suffix.upcase}", '').split
  end
end
