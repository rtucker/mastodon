# frozen_string_literal: true

class FetchMediaWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'bulk', retry: 2

  def perform(media_attachment_id, remote_url: nil, force: false)
    object = MediaAttachment.find(media_attachment_id.to_i)

    return if object&.account.nil? || DomainBlock.reject_media?(object.account.domain)
    return unless force || object.needs_redownload?

    if remote_url.nil?
      return if object.remote_url.nil?
    else
      object.remote_url = remote_url
    end
    object.file_remote_url = object.remote_url
    object.created_at      = Time.now.utc
    object.save!
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    true
  end
end
