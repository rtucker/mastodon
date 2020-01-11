# frozen_string_literal: true

class SearchService < BaseService
  def call(query, account, limit, options = {})
    @query   = query.strip
    @account = account
    @options = options
    @limit   = limit.to_i
    @offset  = options[:type].blank? ? 0 : options[:offset].to_i
    @resolve = options[:resolve] || false

    default_results.tap do |results|
      if url_query?
        results.merge!(url_resource_results) unless url_resource.nil?
      elsif @query.present?
        results[:accounts] = perform_accounts_search! if account_searchable?
        results[:hashtags] = perform_hashtags_search! if hashtag_searchable?
        results[:statuses] = search_for unless @query.start_with?('@', '#')
      end
    end
  end

  private

  def search_for
    results = Status.search_for(@query.gsub(/\A#/, ''), @account, @limit, @offset)
    cache_collection results, Status
  end

  def perform_accounts_search!
    AccountSearchService.new.call(
      @query,
      @account,
      limit: [@limit, 12].min,
      resolve: @resolve,
      offset: @offset
    )
  end

  def perform_hashtags_search!
    Tag.search_for(
      @query.gsub(/\A#/, ''),
      [@limit, 30].min,
      @offset
    )
  end

  def default_results
    { accounts: [], hashtags: [], statuses: [] }
  end

  def url_query?
    @options[:type].blank? && @query =~ /\Ahttps?:\/\//
  end

  def url_resource_results
    { url_resource_symbol => [url_resource] }
  end

  def url_resource
    @_url_resource ||= ResolveURLService.new.call(@query, on_behalf_of: @account)
  end

  def url_resource_symbol
    url_resource.class.name.downcase.pluralize.to_sym
  end

  def full_text_searchable?
    statuses_search? && !@account.nil? && !((@query.start_with?('#') || @query.include?('@')) && !@query.include?(' '))
  end

  def account_searchable?
    account_search? && !(@query.include?('@') && @query.include?(' '))
  end

  def hashtag_searchable?
    hashtag_search? && !@query.include?('@')
  end

  def account_search?
    @options[:type].blank? || @options[:type] == 'accounts'
  end

  def hashtag_search?
    @options[:type].blank? || @options[:type] == 'hashtags'
  end

  def statuses_search?
    @options[:type].blank? || @options[:type] == 'statuses'
  end

  def relations_map_for_account(account, account_ids, domains)
    {
      blocking: Account.blocking_map(account_ids, account.id),
      blocked_by: Account.blocked_by_map(account_ids, account.id),
      muting: Account.muting_map(account_ids, account.id),
      following: Account.following_map(account_ids, account.id),
      domain_blocking_by_domain: Account.domain_blocking_map_by_domain(domains, account.id),
    }
  end

	def cache_collection(raw, klass)
    return raw unless klass.respond_to?(:with_includes)

    raw                    = raw.cache_ids.to_a if raw.is_a?(ActiveRecord::Relation)
    cached_keys_with_value = Rails.cache.read_multi(*raw).transform_keys(&:id)
    uncached_ids           = raw.map(&:id) - cached_keys_with_value.keys

    klass.reload_stale_associations!(cached_keys_with_value.values) if klass.respond_to?(:reload_stale_associations!)

    unless uncached_ids.empty?
      uncached = klass.where(id: uncached_ids).with_includes.each_with_object({}) { |item, h| h[item.id] = item }

      uncached.each_value do |item|
        Rails.cache.write(item, item)
      end
    end

    raw.map { |item| cached_keys_with_value[item.id] || uncached[item.id] }.compact
  end
end
