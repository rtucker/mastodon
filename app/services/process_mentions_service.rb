# frozen_string_literal: true

class ProcessMentionsService < BaseService
  include Payloadable

  # Scan status for mentions and fetch remote mentioned users, create
  # local mention pointers, send Salmon notifications to mentioned
  # remote users
  # @param [Status] status
  def call(status, skip_process: false, skip_notify: false)
    return if status.hidden || !status.local? || status.draft?

    @status  = status
    mentions = Mention.where(status: status).to_a

    unless skip_process
      status.text = status.text.gsub(Account::MENTION_RE) do |match|
        username, domain  = Regexp.last_match(1).split('@')
        mentioned_account = Account.find_remote(username, domain)

        next match unless domain.nil? || '.'.in?(domain)

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
    end

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
    @activitypub_json = Oj.dump(serialize_payload(@status, ActivityPub::ActivitySerializer, signer: @status.account))
  end

  def resolve_account_service
    ResolveAccountService.new
  end
end
