# frozen_string_literal: true

class Api::V1::FiltersController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:filters' }, only: [:index, :show]
  before_action -> { doorkeeper_authorize! :write, :'write:filters' }, except: [:index, :show]
  before_action :require_user!
  before_action :set_filters, only: :index
  before_action :set_filter, only: [:show, :update, :destroy]

  respond_to :json

  def index
    render json: @filters, each_serializer: REST::FilterSerializer
  end

  def create
    @filter = current_account.custom_filters.create!(resource_params)
    toggle_filters
    render json: @filter, serializer: REST::FilterSerializer
  end

  def show
    render json: @filter, serializer: REST::FilterSerializer
  end

  def update
    @filter.update!(resource_params)
    toggle_filters
    render json: @filter, serializer: REST::FilterSerializer
  end

  def destroy
    @filter.destroy!
    toggle_filters
    render_empty
  end

  private

  def toggle_filters
    current_account.user.update!(filters_enabled: !current_account.custom_filters.enabled.blank?)
  end

  def set_filters
    @filters = params['all'].to_i == 1 ? current_account.custom_filters : []
  end

  def set_filter
    @filter = current_account.custom_filters.find(params[:id])
  end

  def resource_params
    params.permit(:phrase, :expires_in, :is_enabled)
  end
end
