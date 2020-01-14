# frozen_string_literal: true

class DefederateStatusWorker
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed

  def perform(defederating_status_id)
    defederating_status = DefederatingStatus.find(defederating_status_id)
    defederating_status.destroy!

    RemoveStatusService.new.call(defederating_status.status, defederate_only: true)
    true
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    true
  end
end
