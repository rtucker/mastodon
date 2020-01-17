# frozen_string_literal: true

class ActivityPub::CollectionsController < Api::BaseController
  include SignatureVerification

  before_action :set_account
  before_action :set_size
  before_action :set_statuses
  before_action :set_cache_headers

  def show
    expires_in 3.minutes
    render_with_cache json: collection_presenter, content_type: 'application/activity+json', serializer: ActivityPub::CollectionSerializer, adapter: ActivityPub::Adapter, skip_activities: true
  end

  private

  def set_account
    @account = Account.find_local!(params[:account_username])
  end

  def set_statuses
    @statuses = scope_for_collection
    @statuses = cache_collection(@statuses, Status)
  end

  def set_size
    case params[:id]
    when 'featured'
      @account.pinned_statuses.where.not(visibility: :private).count
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def scope_for_collection
    case params[:id]
    when 'featured'
      @account.statuses.permitted_for(@account, signed_request_account).tap do |scope|
        scope.merge!(@account.pinned_statuses.where.not(visibility: :private))
      end
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def collection_presenter
    ActivityPub::CollectionPresenter.new(
      id: account_collection_url(@account, params[:id]),
      type: :ordered,
      size: @size,
      items: @statuses
    )
  end
end
