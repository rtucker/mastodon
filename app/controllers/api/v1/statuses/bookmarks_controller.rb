# frozen_string_literal: true

class Api::V1::Statuses::BookmarksController < Api::BaseController
  include Authorization

  before_action -> { doorkeeper_authorize! :write, :'write:bookmarks' }
  before_action :require_user!
  before_action :set_status

  respond_to :json

  def create
    current_account.bookmarks.find_or_create_by!(account: current_account, status: @status)
    curate_status(@status)
    render json: @status, serializer: REST::StatusSerializer, monsterfork_api: monsterfork_api
  end

  def destroy
    bookmark = current_account.bookmarks.find_by(status: @status)
    bookmark&.destroy!

    render json: @status, serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new([@status], current_account.id, bookmarks_map: { @status.id => false }), monsterfork_api: monsterfork_api
  end

  private

  def set_status
    @status = Status.find(params[:status_id])
    authorize @status, :show?
  rescue Mastodon::NotPermittedError
    not_found
  end

  def curate_status(status)
    return if status.curated || !status.distributable? || (status.reply? && status.in_reply_to_account_id != status.account_id)
    status.update(curated: true)
    FanOutOnWriteService.new.call(status)
  end
end
