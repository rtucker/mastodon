# frozen_string_literal: true

class AfterUnblockDomainFromAccountService < BaseService
  def call(account, domain)
    @account = account
    @domain  = domain

    unblock_accounts!
  end

  private

  def unblock_accounts!
    @account.blocking.where(domain: @domain).find_each do |blocked_account|
      UnblockService.new.call(@account, blocked_account)
    end
  end
end
