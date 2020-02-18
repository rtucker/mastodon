# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def reset_password?
    !defanged? && staff? && has_more_authority_than?(record)
  end

  def change_email?
    !defanged? && staff? && has_more_authority_than?(record)
  end

  def disable_2fa?
    !defanged? && admin? && has_more_authority_than?(record)
  end

  def confirm?
    !defanged? && staff? && !record.confirmed?
  end

  def enable?
    !defanged? && staff?
  end

  def approve?
    !defanged? && staff? && !record.approved?
  end

  def reject?
    !defanged? && staff? && !record.approved?
  end

  def disable?
    !defanged? && staff? && has_more_authority_than?(record)
  end

  def promote?
    !defanged? && admin? && promoteable?
  end

  def demote?
    !defanged? && admin? && has_more_authority_than?(record) && demoteable?
  end

  private

  def promoteable?
    record.approved? && !record.can_moderate?
  end

  def demoteable?
    record.can_moderate?
  end
end
