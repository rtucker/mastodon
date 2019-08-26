# frozen_string_literal: true

module Admin
  class PendingAccountsController < BaseController
    before_action :set_accounts, only: :index

    def index
      @form = Form::AccountBatch.new
    end

    def batch
      names = Account.where(id: form_account_batch_params['account_ids'].map(&:to_i)).pluck(:username)

      @form = Form::AccountBatch.new(form_account_batch_params.merge(current_account: current_account, action: action_from_button))
      @form.save

      if action_from_button == 'approve'
        user_friendly_action_log(current_account, :approve_registration, names)
      else
        user_friendly_action_log(current_account, :reject_registration, names)
      end
    rescue ActionController::ParameterMissing
      flash[:alert] = I18n.t('admin.accounts.no_account_selected')
    ensure
      redirect_to admin_pending_accounts_path(current_params)
    end

    def approve_all
      account_ids = User.pending.pluck(:account_id)
      names = Account.where(id: account_ids).pluck(:username)
      Form::AccountBatch.new(current_account: current_account, account_ids: account_ids, action: 'approve').save
      user_friendly_action_log(current_account, :approve_registration, names, "Approved all peneding accounts.")
      redirect_to admin_pending_accounts_path(current_params)
    end

    def reject_all
      account_ids = User.pending.pluck(:account_id)
      names = Account.where(id: account_ids).pluck(:username)
      Form::AccountBatch.new(current_account: current_account, account_ids: account_ids, action: 'reject').save
      user_friendly_action_log(current_account, :reject_registration, names, "Rejected all pending accounts.")
      redirect_to admin_pending_accounts_path(current_params)
    end

    private

    def set_accounts
      @accounts = Account.joins(:user).merge(User.pending.recent).includes(user: :invite_request).page(params[:page])
    end

    def form_account_batch_params
      params.require(:form_account_batch).permit(:action, account_ids: [])
    end

    def action_from_button
      if params[:approve]
        'approve'
      elsif params[:reject]
        'reject'
      end
    end

    def current_params
      params.slice(:page).permit(:page)
    end
  end
end
