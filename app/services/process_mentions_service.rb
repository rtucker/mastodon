# frozen_string_literal: true

class ProcessMentionsService < BaseService
  # Scan status for mentions and fetch remote mentioned users, create
  # local mention pointers
  # @param [Status] status
  def call(status, skip_notify = false)
    return unless status.local? && !status.draft?

    @status  = status
    mentions = Mention.where(status: status).to_a

    status.text = status.text.gsub(Account::MENTION_RE) do |match|
      username, domain  = Regexp.last_match(1).split('@')
      mentioned_account = Account.find_remote(username, domain)

      if mention_undeliverable?(mentioned_account)
        begin
          mentioned_account = resolve_account_service.call(Regexp.last_match(1))
        rescue Goldfinger::Error, HTTP::Error, OpenSSL::SSL::SSLError, Mastodon::UnexpectedResponseError
          mentioned_account = nil
        end
      end

      next match if mention_undeliverable?(mentioned_account) || mentioned_account&.suspended?

      mentions << mentioned_account.mentions.where(status: status).first_or_create(status: status)

      "@#{mentioned_account.acct}"
    end

    status.save!

    return if skip_notify
    mentions.uniq.each { |mention| create_notification(mention) }
  end

  private

  def mention_undeliverable?(mentioned_account)
    mentioned_account.nil?
  end

  def create_notification(mention)
    mentioned_account = mention.account

    if mentioned_account.local?
      LocalNotificationWorker.perform_async(mentioned_account.id, mention.id, mention.class.name)
    elsif !@status.local_only?
      ActivityPub::DeliveryWorker.perform_async(activitypub_json, mention.status.account_id, mentioned_account.inbox_url)
    end
  end

  def activitypub_json
    return @activitypub_json if defined?(@activitypub_json)
    payload = ActiveModelSerializers::SerializableResource.new(
      @status,
      serializer: ActivityPub::ActivitySerializer,
      adapter: ActivityPub::Adapter
    ).as_json
    @activitypub_json = Oj.dump(@status.distributable? ? ActivityPub::LinkedDataSignature.new(payload).sign!(@status.account) : payload)
  end

  def resolve_account_service
    ResolveAccountService.new
  end
end
