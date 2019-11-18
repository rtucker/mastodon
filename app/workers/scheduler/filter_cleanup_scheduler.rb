# frozen_string_literal: true

class Scheduler::FilterCleanupScheduler
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed

  def perform
    CustomFilter.expired.in_batches.destroy_all
  end
end
