# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def index?
    staff?
  end

  def show?
    staff?
  end

  def warn?
    staff? && !record.user&.staff?
  end

  def mark_known?
    staff?
  end

  def mark_unknown?
    staff?
  end

  def manual_only?
    staff?
  end

  def auto_trust?
    staff?
  end

  def suspend?
    staff? && !record.user&.staff?
  end

  def unsuspend?
    staff?
  end

  def silence?
    staff? && !record.user&.staff?
  end

  def unsilence?
    staff?
  end

  def force_unlisted?
    staff?
  end

  def allow_public?
    staff?
  end

  def force_sensitive?
    staff?
  end

  def allow_nonsensitive?
    staff?
  end

  def redownload?
    staff?
  end

  def sync?
    staff?
  end

  def remove_avatar?
    staff?
  end

  def remove_header?
    staff?
  end

  def subscribe?
    admin?
  end

  def unsubscribe?
    admin?
  end

  def memorialize?
    admin? && !record.user&.admin?
  end
end
