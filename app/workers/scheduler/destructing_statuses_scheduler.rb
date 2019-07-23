# frozen_string_literal: true

class Scheduler::DestructingStatusesScheduler
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed, retry: 0

  def perform
    due_statuses.find_each do |destructing_status|
      DestructStatusWorker.perform_at(destructing_status.delete_after, destructing_status.id)
    end
  end

  private

  def due_statuses
    DestructingStatus.where('delete_after <= ?', Time.now.utc + PostStatusService::MIN_DESTRUCT_OFFSET)
  end
end
