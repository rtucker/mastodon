# frozen_string_literal: true

class UnblockDomainService < BaseService
  include Redisable

  attr_accessor :domain_block

  def call(domain_block, destroy_domain_block = true)
    @domain_block = domain_block
    process_retroactive_updates
    clear_filtered_status_cache
    domain_block.destroy if destroy_domain_block
  end

  def process_retroactive_updates
    blocked_accounts.in_batches.update_all(update_options) unless domain_block.noop?
    if @domain_block.force_sensitive?
      blocked_accounts.where(force_sensitive: true).in_batches.update_all(force_sensitive: false)
    end
  end

  def clear_filtered_status_cache
    keys = redis.keys("filtered_statuses:*")
    redis.del(*keys) unless keys.empty?
  end

  def blocked_accounts
    scope = Account.by_domain_and_subdomains(domain_block.domain)

    if domain_block.silence?
      scope.where(silenced_at: @domain_block.created_at)
    else
      scope.where(suspended_at: @domain_block.created_at)
    end
  end

  def update_options
    { domain_block_impact => nil }
  end

  def domain_block_impact
    case @domain_block.severity
    when 'force_unlisted'
      :force_unlisted
    when 'silence'
      :silenced_at
    when 'suspend'
      :suspended_at
    end
  end
end
