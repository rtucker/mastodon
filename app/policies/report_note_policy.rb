# frozen_string_literal: true

class ReportNotePolicy < ApplicationPolicy
  def create?
    !defanged? && staff?
  end

  def destroy?
    (!defanged? && admin?) || owner?
  end

  private

  def owner?
    record.account_id == current_account&.id
  end
end
