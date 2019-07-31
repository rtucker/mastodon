# frozen_string_literal: true

module Admin
  class DomainBlocksController < BaseController
    before_action :set_domain_block, only: [:show, :destroy, :update]

    def new
      authorize :domain_block, :create?
      @domain_block = DomainBlock.new(domain: params[:_domain])
    end

    def create
      authorize :domain_block, :create?

      @domain_block = DomainBlock.new(resource_params)
      existing_domain_block = resource_params[:domain].present? ? DomainBlock.find_by(domain: resource_params[:domain]) : nil

      if existing_domain_block.present?
        @domain_block = existing_domain_block
        @domain_block.update(resource_params.except(:undo))
      end

      if @domain_block.save
        DomainBlockWorker.perform_async(@domain_block.id)
        log_action :create, @domain_block
        redirect_to admin_instance_path(id: @domain_block.domain, limited: '1'), notice: I18n.t('admin.domain_blocks.created_msg')
      else
        render :new
      end
    end

    def show
      authorize @domain_block, :show?
    end

    def destroy
      authorize @domain_block, :destroy?
      DomainUnblockWorker.perform_async(@domain_block.id)
      log_action :destroy, @domain_block
      flash[:notice] = I18n.t('admin.domain_blocks.destroyed_msg')
      redirect_to controller: 'admin/instances', action: 'index', limited: '1'
    end

    def update
      return destroy unless resource_params[:undo].to_i.zero?
      authorize @domain_block, :update?
      @domain_block.update(resource_params.except(:domain, :undo))
      changed = @domain_block.changed
      if @domain_block.save
        DomainBlockWorker.perform_async(@domain_block.id) if (changed & %w(severity force_sensitive reject_media)).any?
        log_action :update, @domain_block
        flash[:notice] = I18n.t('admin.domain_blocks.updated_msg')
      else
        flash[:alert] = I18n.t('admin.domain_blocks.update_failed_msg')
      end
      redirect_to admin_instance_path(id: @domain_block.domain, limited: '1')
    end

    private

    def set_domain_block
      @domain_block = DomainBlock.find(params[:id])
    end

    def resource_params
      params.require(:domain_block).permit(:domain, :severity, :force_sensitive, :reject_media, :reject_reports, :reason, :undo)
    end
  end
end
