# frozen_string_literal: true

class AccountsController < ApplicationController
  PAGE_SIZE = 20

  include AccountControllerConcern

  before_action :set_cache_headers

  def show
    respond_to do |format|
      format.html do
        use_pack 'public'
        mark_cacheable! unless user_signed_in?

        @body_classes      = 'with-modals'
        @pinned_statuses   = []
        @endorsed_accounts = @account.endorsed_accounts.to_a.sample(4)

        if current_account && @account.blocking?(current_account)
          @statuses = []
          return
        end

        @pinned_statuses = cache_collection(@account.pinned_statuses, Status) if show_pinned_statuses?
        @statuses        = filtered_status_page(params)
        @statuses        = cache_collection(@statuses, Status)

        unless @statuses.empty?
          @older_url = older_url if @statuses.last.id > filtered_statuses.last.id
          @newer_url = newer_url if @statuses.first.id < filtered_statuses.first.id
        end
      end

      format.json do
        mark_cacheable!

        render_cached_json(['activitypub', 'actor', @account], content_type: 'application/activity+json') do
          ActiveModelSerializers::SerializableResource.new(@account, serializer: ActivityPub::ActorSerializer, adapter: ActivityPub::Adapter)
        end
      end
    end
  end

  private

  def show_pinned_statuses?
    [reblogs_requested?, replies_requested?, media_requested?, tag_requested?, params[:max_id].present?, params[:min_id].present?].none?
  end

  def filtered_statuses
    if reblogs_requested?
      default_statuses.reblogs
    elsif replies_requested?
      @account.replies ? default_statuses : default_statuses.without_replies
    elsif media_requested?
      default_statuses.where(id: account_media_status_ids)
    elsif tag_requested?
      hashtag_scope
    else
      default_statuses.without_replies.without_reblogs
    end
  end

  def default_statuses
    @account.statuses.not_local_only.where(visibility: [:public, :unlisted])
  end

  def account_media_status_ids
    @account.media_attachments.attached.reorder(nil).select(:status_id).distinct
  end

  def hashtag_scope
    tag = Tag.find_normalized(params[:tag])

    if tag
      return Status.none if !user_signed_in? && (tag.local || tag.private) || tag.private && current_account.id != @account.id
      scope = tag.private ? current_account.statuses : tag.local ? Status.local : Status
      scope.tagged_with(tag.id)
    else
      Status.none
    end
  end

  def username_param
    params[:username]
  end

  def older_url
    pagination_url(max_id: @statuses.last.id)
  end

  def newer_url
    pagination_url(min_id: @statuses.first.id)
  end

  def pagination_url(max_id: nil, min_id: nil)
    if tag_requested?
      short_account_tag_url(@account, params[:tag], max_id: max_id, min_id: min_id)
    elsif media_requested?
      short_account_media_url(@account, max_id: max_id, min_id: min_id)
    elsif replies_requested?
      short_account_with_replies_url(@account, max_id: max_id, min_id: min_id)
    elsif reblogs_requested?
      short_account_reblogs_url(@account, max_id: max_id, min_id: min_id)
    else
      short_account_url(@account, max_id: max_id, min_id: min_id)
    end
  end

  def media_requested?
    request.path.ends_with?('/media')
  end

  def replies_requested?
    request.path.ends_with?('/with_replies')
  end

  def reblogs_requested?
    request.path.ends_with?('/reblogs')
  end

  def tag_requested?
    request.path.ends_with?(Addressable::URI.parse("/tagged/#{params[:tag]}").normalize)
  end

  def filtered_status_page(params)
    if params[:min_id].present?
      filtered_statuses.paginate_by_min_id(PAGE_SIZE, params[:min_id]).reverse
    else
      filtered_statuses.paginate_by_max_id(PAGE_SIZE, params[:max_id], params[:since_id]).to_a
    end
  end
end
