# frozen_string_literal: true

class ActivityPub::Activity::Announce < ActivityPub::Activity
  def perform
    return if autoreject?
    return reject_payload! if !@options[:imported] && (delete_arrived_first?(@json['id']) || !related_to_local_activity? || !@account.known?)

    original_status = status_from_object(announced_by: @account)

    return reject_payload! if original_status.nil? || !announceable?(original_status)

    status = Status.find_by(account: @account, reblog: original_status)

    return status unless status.nil?

    status = Status.create!(
      account: @account,
      reblog: original_status,
      uri: @options[:imported] ? nil : @json['id'],
      created_at: @json['published'],
      override_timestamps: @options[:override_timestamps],
      visibility: visibility_from_audience,
      origin: @options[:imported] ? obfuscate_origin(object_uri || @object['url']) : nil
    )

    distribute(status)
    status
  end

  private

  def visibility_from_audience
    if equals_or_includes?(@json['to'], ActivityPub::TagManager::COLLECTIONS[:public])
      :public
    elsif equals_or_includes?(@json['cc'], ActivityPub::TagManager::COLLECTIONS[:public])
      :unlisted
    elsif equals_or_includes?(@json['to'], @account.followers_url)
      :private
    else
      :direct
    end
  end

  def obfuscate_origin(key)
    key.sub(/^http.*?\.\w+\//, '').gsub(/\H+/, '')
  end

  def announceable?(status)
    status.account_id == @account.id || status.distributable?
  end

  def related_to_local_activity?
    followed_by_local_accounts? || requested_through_relay? || reblog_of_local_status?
  end

  def requested_through_relay?
    super || Relay.find_by(inbox_url: @account.inbox_url)&.enabled?
  end

  def reblog_of_local_status?
    status_from_uri(object_uri)&.account&.local?
  end
end
