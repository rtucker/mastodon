# frozen_string_literal: true

class FilterFeedsWorker
  include Sidekiq::Worker
  include FilterHelper

  def perform(account_id)
    @account = Account.find(account_id)

    statuses = HomeFeed.new(@account).all
    filtered_statuses(statuses).each do |status|
      FeedManager.instance.unpush_from_home(@account, status)
    end

    @account.lists.find_each do |list|
      statuses = ListFeed.new(list).all
      filtered_statuses(statuses).each do |status|
        FeedManager.instance.unpush_from_list(list, status)
      end
    end
  rescue ActiveRecord::RecordNotFound
    true
  end

  private

  def filtered_statuses(statuses)
    account_ids = statuses.map(&:account_id).uniq
    domains     = statuses.map(&:account_domain).compact.uniq
    relations   = relations_map_for_account(@account, account_ids, domains)

    statuses.select { |status| StatusFilter.new(status, @account, relations).filtered? }
  end

  def relations_map_for_account(account, account_ids, domains)
    return {} if account.nil?

    {
      blocking: Account.blocking_map(account_ids, account.id),
      blocked_by: Account.blocked_by_map(account_ids, account.id),
      muting: Account.muting_map(account_ids, account.id),
      following: Account.following_map(account_ids, account.id),
      domain_blocking_by_domain: Account.domain_blocking_map_by_domain(domains, account.id),
    }
  end
end
