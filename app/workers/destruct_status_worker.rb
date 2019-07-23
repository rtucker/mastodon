# frozen_string_literal: true

class DestructStatusWorker
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed

  def perform(destructing_status_id)
    destructing_status = DestructingStatus.find(destructing_status_id)
    destructing_status.destroy!

    RemoveStatusService.new.call(destructing_status.status)
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    true
  end
end
