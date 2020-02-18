# frozen_string_literal: true

module UserRoles
  extend ActiveSupport::Concern

  included do
    scope :admins, -> { where(admin: true) }
    scope :moderators, -> { where(moderator: true) }
    scope :halfmods, -> { where(halfmod: true) }
    scope :staff, -> { admins.or(moderators) }
  end

  def staff?
    admin? || moderator?
  end

  def can_moderate?
    staff? || halfmod?
  end

  def role
    if admin?
      'admin'
    elsif moderator?
      'moderator'
    elsif halfmod?
      'halfmod'
    else
      'user'
    end
  end

  def role?(role)
    case role
    when 'user'
      true
    when 'halfmod'
      halfmod?
    when 'moderator'
      staff?
    when 'admin'
      admin?
    else
      false
    end
  end

  def has_more_authority_than?(other_user)
    if admin?
      !other_user&.admin?
    elsif moderator?
      !other_user&.staff?
    elsif halfmod?
      !other_user&.can_moderate?
    else
      false
    end
  end

  def promote!
    if halfmod?
      update!(halfmod: false, moderator: true, admin: false)
    elsif moderator?
      update!(halfmod: false, moderator: false, admin: true)
    elsif !admin?
      update!(halfmod: true, moderator: false, admin: false)
    end
  end

  def demote!
    if admin?
      update!(halfmod: false, moderator: true, admin: false)
    elsif moderator?
      update!(halfmod: true, moderator: false, admin: false)
    elsif halfmod?
      update!(halfmod: false, moderator: false, admin: false)
    end
  end

  def fangs_out!
    update!(defanged: false, last_fanged_at: Time.now.utc)
    LogWorker.perform_async("\u23eb <#{self.account.username}> switched to fanged #{role} mode.")
  end

  def defang!
    update!(defanged: true, last_fanged_at: nil)
    LogWorker.perform_async("\u23ec <#{self.account.username}> is no longer in fanged #{role} mode.")
  end
end
