# frozen_string_literal: true

class UpdateAccountDomainBlocksWorker
  include Sidekiq::Worker

  def perform(account_id)
    UpdateAccountDomainBlocksService.new.call(Account.find(account_id))
  rescue ActiveRecord::RecordNotFound
    true
  end
end
