# frozen_string_literal: true

class DomainBlockPolicy < ApplicationPolicy
  def index?
    !defanged? && staff?
  end

  def show?
    !defanged? && staff?
  end

  def create?
    !defanged? && staff?
  end

  def destroy?
    !defanged? && staff?
  end

  def update?
    !defanged? && staff?
  end
end
