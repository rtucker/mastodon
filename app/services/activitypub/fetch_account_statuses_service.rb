# frozen_string_literal: true

class ActivityPub::FetchAccountStatusesService < BaseService
  include JsonLdHelper

  MAX_PAGES = 50

  def call(account, url = nil)
    @account = account
    return if account.local? || account.suspended?

    page = 1

    @json = fetch_collection(url || account.outbox_url)
    @items = Rails.cache.fetch("account_sync:#{account.id}") || []

    if @items.empty?
      until page == MAX_PAGES || @json.blank?
        items = collection_items(@json).select { |item| item['type'] == 'Create' }
        @items.concat(items)
        break if @json['next'].blank?
        page += 1
        @json = fetch_collection(@json['next'])
      end
    end

    Rails.cache.write("account_sync:#{account.id}", @items, expires_in: 1.day)
    process_items(@items)
    Rails.cache.delete("account_sync:#{account.id}")

    @items
  end

  private

  def fetch_collection(collection_or_uri)
    return collection_or_uri if collection_or_uri.is_a?(Hash)

    collection = _fetch_collection(collection_or_uri)
    return unless collection.is_a?(Hash)

    if collection['first'].present?
      collection = _fetch_collection(collection['first'])
      return unless collection.is_a?(Hash)
    end

    collection
  end

  def _fetch_collection(collection_or_uri)
    return collection_or_uri if collection_or_uri.is_a?(Hash)
    return if invalid_origin?(collection_or_uri)
    fetch_resource_without_id_validation(collection_or_uri, nil, true)
  end

  def collection_items(collection)
    case collection['type']
    when 'Collection', 'CollectionPage'
      collection['items']
    when 'OrderedCollection', 'OrderedCollectionPage'
      collection['orderedItems']
    end
  end

  def process_items(items)
    items.reverse_each.map { |item| process_item(item) }.compact
  end

  def process_item(item)
    return unless item.is_a?(Hash) && item['type'].present?
    ActivityPub::Activity.factory(item, @account, override_timestamps: true, requested: true)&.perform
  rescue => e
    Rails.logger.error("Failed to process #{item['type']} #{item['id']} due to #{e}: #{e.message}")
    Rails.logger.error("Stack trace: #{backtrace.map {|l| "  #{l}\n"}.join}")
  end
end
