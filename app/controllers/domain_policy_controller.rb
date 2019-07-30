# frozen_string_literal: true

class DomainPolicyController < ApplicationController
  before_action :authenticate_user!

  before_action :set_pack
  layout 'public'

  before_action :set_instance_presenter, only: [:show]

  def show
    @hide_navbar = true
    @domain_policies = DomainBlock.all
  end

  private

  def set_pack
    use_pack 'common'
  end

  def set_instance_presenter
    @instance_presenter = InstancePresenter.new
  end

  def authenticate_user!
    return if user_signed_in?
    not_found
  end
end
