# frozen_string_literal: true

class RemoteInteractionController < ApplicationController
  include Authorization

  layout 'modal'

  before_action :set_body_classes
  before_action :set_pack
  before_action :set_status

  def new
    raise Mastodon::NotPermittedError unless user_signed_in?

    case params[:type]
    when 'reblog'
      if current_account.statuses.where(reblog: @status).exists?
        status = current_account.statuses.find_by(reblog: @status)
        RemoveStatusService.new.call(status)
      else
        ReblogService.new.call(current_account, @status)
      end
    when 'favourite'
      if Favourite.where(account: current_account, status: @status).exists?
        UnfavouriteService.new.call(current_account, @status)
      else
        FavouriteService.new.call(current_account, @status, skip_authorize: true)
      end
    when 'follow'
      FollowService.new.call(current_account, @status.account)
    when 'unfollow'
      UnfollowService.new.call(current_account, @status.account)
    end

    redirect_to short_account_status_url(@status.account.username, @status.id, key: @sharekey)
  end

  private

  def resource_params
    params.require(:remote_follow).permit(:acct)
  end

  def session_params
    { acct: session[:remote_follow] }
  end

  def set_status
    @status = Status.find(params[:id])
    @sharekey = params[:key]

    if @status.sharekey.present? && @sharekey == @status.sharekey
      skip_authorization
    else
      authorize @status, :show?
    end
  rescue Mastodon::NotPermittedError
    # Reraise in order to get a 404
    raise ActiveRecord::RecordNotFound
  end

  def set_body_classes
    @body_classes = 'modal-layout'
    @hide_header  = true
  end

  def set_pack
    use_pack 'modal'
  end
end
