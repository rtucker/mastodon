# frozen_string_literal: true

class SyncRemoteAccountWorker
  include Sidekiq::Worker

  def perform(account_id)
    account = Account.find(account_id)
    ActivityPub::FetchAccountStatusesService.new.call(account)
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    true
  end
end
