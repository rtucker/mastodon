# frozen_string_literal: true

class RegistrationJanitorWorker
  include Sidekiq::Worker
  include LogHelper

  def perform(user_id)
    user = User.find(user_id)
    janitor = janitor_account || Account.representative

    spam_triggers = ENV.fetch('REGISTRATION_SPAM_TRIGGERS', '').split('|').map { |phrase| phrase.strip }

    intro = user.invite_request&.text
    # normalize it
    intro = intro.gsub(/[\u200b-\u200d\ufeff\u200e\u200f]/, '').strip.downcase unless intro.nil?

    return user.notify_staff_about_pending_account! unless intro.blank? || intro.split.count < 5 || spam_triggers.any? { |phrase| phrase.in?(intro) }

    user_friendly_action_log(janitor, :reject_registration, user.account.username, "Registration was spam filtered.")
    Form::AccountBatch.new(current_account: janitor, account_ids: user.account.id, action: 'reject').save
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    true
  end

  private

  def janitor_account
    account_id = ENV.fetch('JANITOR_USER', '').to_i
    return if account_id == 0
    Account.find_by(id: account_id)
  end
end
