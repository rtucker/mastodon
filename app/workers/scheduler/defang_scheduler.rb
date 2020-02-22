# frozen_string_literal: true

class Scheduler::DefangScheduler
  include Sidekiq::Worker
  include ServiceAccountHelper

  def perform
    User.where(defanged: false, last_fanged_at: nil).or(User.where('last_fanged_at <= ?', 15.minutes.ago)) do
      |user| user.defang!
      next unless user&.account.present?
      service_dm('announcements', user.account, "You are no longer in #{user.role} mode.", footer: 'auto-defang')
    end
  end
end
