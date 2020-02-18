# frozen_string_literal: true

class SettingsPolicy < ApplicationPolicy
  def update?
    !defanged? && admin?
  end

  def show?
    !defanged? && admin?
  end
end
