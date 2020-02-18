# frozen_string_literal: true

class InstancePolicy < ApplicationPolicy
  def index?
    !defanged? && admin?
  end

  def show?
    !defanged? && admin?
  end
end
