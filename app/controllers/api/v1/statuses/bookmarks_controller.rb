# frozen_string_literal: true

class Api::V1::Statuses::BookmarksController < Api::BaseController
  include Authorization

  before_action -> { doorkeeper_authorize! :write, :'write:bookmarks' }
  before_action :require_user!

  respond_to :json

  def create
    @status = bookmarked_status
    render json: @status, serializer: REST::StatusSerializer, monsterfork_api: monsterfork_api
  end

  def destroy
    @status = requested_status
    @bookmarks_map = { @status.id => false }

    bookmark = Bookmark.find_by!(account: current_user.account, status: @status)
    bookmark.destroy!

    render json: @status, serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new([@status], current_user&.account_id, bookmarks_map: @bookmarks_map), monsterfork_api: monsterfork_api
  end

  private

  def bookmarked_status
    authorize_with current_user.account, requested_status, :show?

    bookmark = Bookmark.find_or_create_by!(account: current_user.account, status: requested_status)

    curate_status(requested_status)

    bookmark.status.reload
  end

  def requested_status
    Status.find(params[:status_id])
  end

  def curate_status(status)
    return if status.curated || !status.distributable? || (status.reply? && status.in_reply_to_account_id != status.account_id)
    status.update(curated: true)
    FanOutOnWriteService.new.call(status)
  end
end
