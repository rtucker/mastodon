# frozen_string_literal: true

class TagPolicy < ApplicationPolicy
  def index?
    !defanged? && can_moderate?
  end

  def hide?
    !defanged? && can_moderate?
  end

  def unhide?
    !defanged? && can_moderate?
  end
end
