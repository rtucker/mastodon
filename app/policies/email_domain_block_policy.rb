# frozen_string_literal: true

class EmailDomainBlockPolicy < ApplicationPolicy
  def index?
    !defanged? && staff?
  end

  def create?
    !defanged? && staff?
  end

  def destroy?
    !defanged? && staff?
  end
end
