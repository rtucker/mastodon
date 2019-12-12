# frozen_string_literal: true

class PostStatusWorker
  include Sidekiq::Worker

  def perform(status_id, options = {})
    status = Status.find(status_id)
    return false if status.destroyed?

    status.update(options.slice(:visibility, :local_only, :reject_replies).compact)
    process_mentions_service.call(status, skip_process: true) unless options[:nomentions]

    LinkCrawlWorker.perform_async(status.id) unless options[:nocrawl] || status.spoiler_text.present?
    DistributionWorker.perform_async(status.id) unless options[:distribute] == false

    unless status.local_only? || options[:distribute] == false || options[:federate] == false
      ActivityPub::DistributionWorker.perform_async(status.id)
    end

    PollExpirationNotifyWorker.perform_at(status.poll.expires_at, status.poll.id) if status.poll

    status.delete_after = options[:delete_after] if options[:delete_after]

    return true if !status.reply? || status.account.id == status.in_reply_to_account_id
    ActivityTracker.increment('activity:interactions')
    return if status.account.following?(status.in_reply_to_account_id)
    PotentialFriendshipTracker.record(status.account.id, status.in_reply_to_account_id, :reply)

    true
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    true
  end

  private

  def process_mentions_service
    ProcessMentionsService.new
  end
end
