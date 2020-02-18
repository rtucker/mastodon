# frozen_string_literal: true

class AccountModerationNotePolicy < ApplicationPolicy
  def create?
    !defanged? && can_moderate?
  end

  def destroy?
    (!defanged? && admin?) || owner?
  end

  private

  def owner?
    record.account_id == current_account&.id
  end
end
