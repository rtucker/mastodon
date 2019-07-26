# frozen_string_literal: true

class Scheduler::DestructingStatusesScheduler
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed, retry: 0

  def perform
    due_statuses.find_each do |destructing_status|
      DestructStatusWorker.perform_async(destructing_status.id)
    end
  end

  private

  def due_statuses
    DestructingStatus.where('delete_after <= ?', Time.now.utc)
  end
end
