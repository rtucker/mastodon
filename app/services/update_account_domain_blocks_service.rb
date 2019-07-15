# frozen_string_literal: true

class UpdateAccountDomainBlocksService < BaseService
  def call(account)
    @account = account
    @domain  = account.domain

    block_where_domain_blocked!
  end

  private

  def block_where_domain_blocked!
    account_ids = AccountDomainBlock.distinct.where(domain: @domain).pluck(:account_id)
    Account.where(id: account_ids).find_each do |blocked_by|
      BlockService.new.call(blocked_by, @account)
    end
  end
end
