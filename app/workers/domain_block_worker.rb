# frozen_string_literal: true

class DomainBlockWorker
  include Sidekiq::Worker

  def perform(domain_block_id)
    domain_block = DomainBlock.find(domain_block_id)
    BlockDomainService.new.call(domain_block)
  rescue ActiveRecord::RecordNotFound
    true
  end
end
