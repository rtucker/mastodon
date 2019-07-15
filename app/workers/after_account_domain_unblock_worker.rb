# frozen_string_literal: true

class AfterAccountDomainUnblockWorker
  include Sidekiq::Worker

  def perform(account_id, domain)
    AfterUnblockDomainFromAccountService.new.call(Account.find(account_id), domain)
  rescue ActiveRecord::RecordNotFound
    true
  end
end
