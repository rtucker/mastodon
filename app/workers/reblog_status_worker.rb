# frozen_string_literal: true

class ReblogStatusWorker
  include Sidekiq::Worker

  def perform(account_id, status_id, reblog_params = {})
    account = Account.find(account_id)
    status = Status.find(status_id)
    return false if status.destroyed? || !status.distributable?
    ReblogService.new.call(account, status, reblog_params.symbolize_keys)
    true
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, Mastodon::NotPermittedError
    true
  end
end
