# frozen_string_literal: true

module AccountableConcern
  extend ActiveSupport::Concern
  include LogHelper

  def log_action(action, target)
    Admin::ActionLog.create(account: current_account, action: action, target: target)
    user_friendly_action_log(current_account, action, target)
  end
end
