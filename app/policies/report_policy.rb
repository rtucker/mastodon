# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  def update?
    !defanged? && staff?
  end

  def index?
    !defanged? && staff?
  end

  def show?
    !defanged? && staff?
  end
end
