# frozen_string_literal: true

class Scheduler::DomainPolicyScheduler
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed

  def perform
    DomainBlock.unprocessed.find_each { |policy| BlockDomainService.new.call(policy) }
  end
end
