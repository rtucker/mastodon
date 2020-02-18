# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def index?
    !defanged? && can_moderate?
  end

  def show?
    !defanged? && can_moderate?
  end

  def warn?
    !defanged? && staff? && has_more_authority_than?(record&.user)
  end

  def mark_known?
    !defanged? && can_moderate? && has_more_authority_than?(record&.user)
  end

  def mark_unknown?
    !defanged? && can_moderate? && has_more_authority_than?(record&.user)
  end

  def manual_only?
    !defanged? && can_moderate? && has_more_authority_than?(record&.user)
  end

  def auto_trust?
    !defanged? && can_moderate? && has_more_authority_than?(record&.user)
  end

  def suspend?
    !defanged? && staff? && has_more_authority_than?(record&.user)
  end

  def unsuspend?
    !defanged? && staff? && has_more_authority_than?(record&.user)
  end

  def silence?
    !defanged? && can_moderate? && has_more_authority_than?(record.user)
  end

  def unsilence?
    !defanged? && can_moderate? && has_more_authority_than?(record&.user)
  end

  def force_unlisted?
    !defanged? && staff? && has_more_authority_than?(record&.user)
  end

  def allow_public?
    !defanged? && can_moderate? && has_more_authority_than?(record&.user)
  end

  def force_sensitive?
    !defanged? && staff? && has_more_authority_than?(record&.user)
  end

  def allow_nonsensitive?
    !defanged? && can_moderate? && has_more_authority_than?(record&.user)
  end

  def redownload?
    !defanged? && can_moderate?
  end

  def sync?
    !defanged? && can_moderate?
  end

  def remove_avatar?
    !defanged? && can_moderate? && has_more_authority_than?(record&.user)
  end

  def remove_header?
    !defanged? && can_moderate? && has_more_authority_than?(record&.user)
  end

  def subscribe?
    !defanged? && admin?
  end

  def unsubscribe?
    !defanged? && admin?
  end

  def memorialize?
    !defanged? && staff? && !record.user&.staff?
  end
end
