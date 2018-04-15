# frozen_string_literal: true

class CustomEmojiPolicy < ApplicationPolicy
  def index?
    staff?
  end

  def create?
    staff?
  end

  def update?
    staff?
  end

  def copy?
    staff?
  end

  def enable?
    staff?
  end

  def disable?
    staff?
  end

  def destroy?
    staff?
  end
end
