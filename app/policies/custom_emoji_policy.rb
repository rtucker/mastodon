# frozen_string_literal: true

class CustomEmojiPolicy < ApplicationPolicy
  def index?
    user_signed_in?
  end

  def create?
    user_signed_in?
  end

  def update?
    can_moderate?
  end

  def copy?
    user_signed_in?
  end

  def enable?
    can_moderate?
  end

  def disable?
    can_moderate?
  end

  def destroy?
    staff?
  end
end
