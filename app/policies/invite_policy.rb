# frozen_string_literal: true

class InvitePolicy < ApplicationPolicy
  def index?
    !defanged? && can_moderate?
  end

  def create?
    min_required_role?
  end

  def deactivate_all?
    !defanged? && admin?
  end

  def destroy?
    owner? || (!defanged? && (Setting.min_invite_role == 'admin' ? admin? : can_moderate?))
  end

  private

  def owner?
    record.user_id == current_user&.id
  end

  def min_required_role?
    current_user&.role?(Setting.min_invite_role)
  end
end
