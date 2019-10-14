# frozen_string_literal: true

class Api::V1::Instances::PeersController < Api::BaseController
  before_action :require_enabled_api!
  skip_before_action :set_cache_headers

  respond_to :json

  def index
    render_cached_json('api:v1:instances:peers:index', expires_in: 1.day) { actively_federated_domains }
  end

  private

  def actively_federated_domains
    blocks = DomainBlock.suspend
    Account.remote.where(suspended_at: nil).domains.reject { |domain| blocks.where('domain LIKE ?', "%.#{domain}").exists? }
  end

  def require_enabled_api!
    head 404 unless Setting.peers_api_enabled
  end
end
