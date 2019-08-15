# frozen_string_literal: true

class RemoteFollowController < ApplicationController
  layout 'modal'

  before_action :set_account
  before_action :set_pack
  before_action :gone, if: :suspended_account?
  before_action :set_body_classes

  def new
    raise Mastodon::NotPermittedError unless user_signed_in?

    FollowService.new.call(current_account, @account) unless current_account.following?(@account)
    redirect_to TagManager.instance.url_for(@account)
  end

  private

  def resource_params
    params.require(:remote_follow).permit(:acct)
  end

  def session_params
    { acct: session[:remote_follow] }
  end

  def set_pack
    use_pack 'modal'
  end

  def set_account
    @account = Account.find_local!(params[:account_username])
  end

  def suspended_account?
    @account.suspended?
  end

  def set_body_classes
    @body_classes = 'modal-layout'
    @hide_header  = true
  end
end
