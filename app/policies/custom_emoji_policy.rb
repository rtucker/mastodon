# frozen_string_literal: true

class CustomEmojiPolicy < ApplicationPolicy
  def index?
    user_signed_in?
  end

  def create?
    user_signed_in?
  end

  def update?
    staff?
  end

  def copy?
    user_signed_in?
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
