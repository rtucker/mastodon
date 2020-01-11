# frozen_string_literal: true

class Api::V1::Timelines::TagController < Api::BaseController
  before_action :load_tag
  after_action :insert_pagination_headers, unless: -> { @statuses.empty? }

  respond_to :json

  def show
    @statuses = load_statuses
    render json: @statuses, each_serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id), monsterfork_api: monsterfork_api
  end

  private

  def load_tag
    @tag = Tag.find_normalized(params[:id])
  end

  def load_statuses
    cached_tagged_statuses
  end

  def cached_tagged_statuses
    cache_collection tagged_statuses, Status
  end

  def tagged_statuses
    if @tag.nil?
      []
    elsif @tag.name.in?(['self.bookmarks', '.self.bookmarks'])
      Status.reorder(nil).joins(:bookmarks).merge(bookmark_results)
    elsif @tag.name.in?(['self.boosts', '.self.boosts'])
      reblog_results
    elsif @tag.name.in?(['self.home.boosts', '.self.home.boosts'])
      home_reblog_results
    else
      statuses = tag_timeline_statuses.paginate_by_id(
        limit_param(DEFAULT_STATUSES_LIMIT),
        params_slice(:max_id, :since_id, :min_id)
      )

      if truthy_param?(:only_media)
        # `SELECT DISTINCT id, updated_at` is too slow, so pluck ids at first, and then select id, updated_at with ids.
        status_ids = statuses.joins(:media_attachments).distinct(:id).pluck(:id)
        statuses.where(id: status_ids)
      else
        statuses
      end
    end
  end

  def tag_timeline_statuses
    statuses = HashtagQueryService.new.call(@tag, params.slice(:any, :all, :none), current_account, truthy_param?(:local))
  end

  def bookmark_results
    account_bookmarks.paginate_by_max_id(
      limit_param(DEFAULT_STATUSES_LIMIT),
      params[:max_id],
      params[:since_id]
    )
  end

  def account_bookmarks
    current_account.bookmarks
  end

  def reblog_results
    account_reblogs.paginate_by_max_id(
      limit_param(DEFAULT_STATUSES_LIMIT),
      params[:max_id],
      params[:since_id]
    )
  end

  def account_reblogs
    current_account.statuses.reblogs
  end

  def home_reblog_results
    account_home_reblogs.paginate_by_max_id(
      limit_param(DEFAULT_STATUSES_LIMIT),
      params[:max_id],
      params[:since_id]
    )
  end

  def account_home_reblogs
    Status.as_home_timeline(current_account, reblogs_only: true)
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def pagination_params(core_params)
    params.slice(:local, :limit, :only_media).permit(:local, :limit, :only_media).merge(core_params)
  end

  def next_path
    api_v1_timelines_tag_url params[:id], pagination_params(max_id: pagination_max_id)
  end

  def prev_path
    api_v1_timelines_tag_url params[:id], pagination_params(min_id: pagination_since_id)
  end

  def pagination_max_id
    @statuses.last.id
  end

  def pagination_since_id
    @statuses.first.id
  end
end
