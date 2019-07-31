# frozen_string_literal: true

class DomainUnblockWorker
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed

  def perform(domain_block_id)
    UnblockDomainService.new.call(DomainBlock.find(domain_block_id))
  rescue ActiveRecord::RecordNotFound
    true
  end
end
