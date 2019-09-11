# frozen_string_literal: true

module Admin
  class AccountsController < BaseController
    before_action :set_account, only: [:show, :redownload, :remove_avatar, :remove_header, :enable, :mark_known, :mark_unknown, :manual_only, :auto_trust, :allow_public, :allow_nonsensitive, :unsilence, :unsuspend, :memorialize, :approve, :reject, :sync]
    before_action :require_remote_account!, only: [:redownload, :sync]
    before_action :require_local_account!, only: [:enable, :memorialize, :approve, :reject]

    def index
      authorize :account, :index?
      @accounts = filtered_accounts.page(params[:page])
    end

    def show
      authorize @account, :show?

      @account_moderation_note = current_account.account_moderation_notes.new(target_account: @account)
      @moderation_notes        = @account.targeted_moderation_notes.latest
      @warnings                = @account.targeted_account_warnings.latest.custom
    end

    def memorialize
      authorize @account, :memorialize?
      @account.memorialize!
      log_action :memorialize, @account
      redirect_to admin_account_path(@account.id)
    end

    def enable
      authorize @account.user, :enable?
      @account.user.enable!
      log_action :enable, @account.user
      redirect_to admin_account_path(@account.id)
    end

    def approve
      authorize @account.user, :approve?
      @account.user.approve!
      redirect_to admin_pending_accounts_path
    end

    def reject
      authorize @account.user, :reject?
      SuspendAccountService.new.call(@account, reserve_email: false, reserve_username: false)
      redirect_to admin_pending_accounts_path
    end

    def mark_unknown
      authorize @account, :mark_unknown?
      @account.mark_unknown!
      log_action :mark_unknown, @account
      redirect_to admin_account_path(@account.id)
    end

    def mark_known
      authorize @account, :mark_known?
      @account.mark_known!
      log_action :mark_known, @account
      redirect_to admin_account_path(@account.id)
    end

    def manual_only
      authorize @account, :manual_only?
      @account.manual_only!
      log_action :manual_only, @account
      redirect_to admin_account_path(@account.id)
    end

    def auto_trust
      authorize @account, :auto_trust?
      @account.auto_trust!
      log_action :auto_trust, @account
      redirect_to admin_account_path(@account.id)
    end

    def force_sensitive
      authorize @account, :force_sensitive?
      @account.force_sensitive!
      log_action :force_sensitive, @account
      redirect_to admin_account_path(@account.id)
    end

    def allow_nonsensitive
      authorize @account, :allow_nonsensitive?
      @account.allow_nonsensitive!
      log_action :allow_nonsensitive, @account
      redirect_to admin_account_path(@account.id)
    end

    def force_unlisted
      authorize @account, :force_unlisted?
      @account.force_unlisted!
      log_action :force_unlisted, @account
      redirect_to admin_account_path(@account.id)
    end

    def allow_public
      authorize @account, :allow_public?
      @account.allow_public!
      log_action :allow_public, @account
      redirect_to admin_account_path(@account.id)
    end

    def unsilence
      authorize @account, :unsilence?
      @account.unsilence!
      log_action :unsilence, @account
      redirect_to admin_account_path(@account.id)
    end

    def unsuspend
      authorize @account, :unsuspend?
      @account.unsuspend!
      log_action :unsuspend, @account
      redirect_to admin_account_path(@account.id)
    end

    def redownload
      authorize @account, :redownload?

      @account.update!(last_webfingered_at: nil)
      ResolveAccountService.new.call(@account)

      redirect_to admin_account_path(@account.id)
    end

    def sync
      authorize @account, :sync?

      @account.update!(last_webfingered_at: nil)
      ResolveAccountService.new.call(@account)
      SyncRemoteAccountWorker.perform_async(@account.id)

      redirect_to admin_account_path(@account.id)
    end

    def remove_avatar
      authorize @account, :remove_avatar?

      @account.avatar = nil
      @account.save!

      log_action :remove_avatar, @account.user

      redirect_to admin_account_path(@account.id)
    end

    def remove_header
      authorize @account, :remove_header?

      @account.header = nil
      @account.save!

      log_action :remove_header, @account.user

      redirect_to admin_account_path(@account.id)
    end

    private

    def set_account
      @account = Account.find(params[:id])
    end

    def require_remote_account!
      redirect_to admin_account_path(@account.id) if @account.local?
    end

    def require_local_account!
      redirect_to admin_account_path(@account.id) unless @account.local? && @account.user.present?
    end

    def filtered_accounts
      AccountFilter.new(filter_params).results
    end

    def filter_params
      params.permit(
        :local,
        :remote,
        :by_domain,
        :active,
        :pending,
        :silenced,
        :suspended,
        :username,
        :display_name,
        :email,
        :ip,
        :staff
      )
    end
  end
end
