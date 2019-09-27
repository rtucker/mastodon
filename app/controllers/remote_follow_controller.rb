# frozen_string_literal: true

class RemoteFollowController < ApplicationController
  include AccountOwnedConcern

  layout 'modal'

  before_action :set_pack
  before_action :set_body_classes

  skip_before_action :require_functional!

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

  def set_body_classes
    @body_classes = 'modal-layout'
    @hide_header  = true
  end
end
