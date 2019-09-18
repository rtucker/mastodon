# frozen_string_literal: true

class FetchAvatarMediaWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'bulk', retry: 2

  def perform(account_id)
    account = Account.find(account_id)
    return if account.suspended_at?
    account.reset_avatar! unless account.avatar_remote_url.nil?
    account.reset_header! unless account.header_remote_url.nil?
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    true
  end
end
