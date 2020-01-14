# frozen_string_literal: true

class Scheduler::DefederatingStatusesScheduler
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed, retry: 0

  def perform
    due_statuses.find_each do |defederating_status|
      DefederateStatusWorker.perform_async(defederating_status.id)
    end
  end

  private

  def due_statuses
    DefederatingStatus.where('defederate_after <= ?', Time.now.utc)
  end
end
