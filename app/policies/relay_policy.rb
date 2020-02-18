# frozen_string_literal: true

class RelayPolicy < ApplicationPolicy
  def update?
    !defanged? && admin?
  end
end
