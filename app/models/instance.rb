# frozen_string_literal: true

class Instance
  include ActiveModel::Model

  attr_accessor :domain, :accounts_count, :domain_block, :updated_at

  def initialize(resource)
    @domain         = resource.domain
    @accounts_count = resource.respond_to?(:accounts_count) ? resource.accounts_count : nil
    @domain_block   = resource.is_a?(DomainBlock) ? resource : DomainBlock.rule_for(domain)
    @domain_allow   = resource.is_a?(DomainAllow) ? resource : DomainAllow.rule_for(domain)
    @updated_at     = resource.is_a?(DomainBlock) ? resource.updated_at : 0
  end

  def cached_sample_accounts
    Rails.cache.fetch("#{cache_key}/sample_accounts", expires_in: 12.hours) { Account.where(domain: domain).searchable.joins(:account_stat).popular.limit(3) }
  end

  def cached_accounts_count
    @accounts_count || Rails.cache.fetch("#{cache_key}/count", expires_in: 12.hours) { Account.where(domain: domain).count }
  end

  def to_param
    domain
  end

  def cache_key
    domain
  end
end
