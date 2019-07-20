# frozen_string_literal: true

class StatusPolicy < ApplicationPolicy
  def initialize(current_account, record, preloaded_relations = {})
    super(current_account, record)

    @preloaded_relations = preloaded_relations
  end

  def index?
    staff?
  end

  def show?
    return false if local_only? && (current_account.nil? || !current_account.local?)
    return true if owned? || mention_exists?
    return false if direct?

    if private?
      following_author? && still_accessible?
    else
      author_allows_anon? && still_accessible? && (!author_blocking? && !author_blocking_domain?) || following_author?
    end
  end

  def reblog?
    !direct? && (!private? || owned?) && show? && !blocking_author?
  end

  def favourite?
    show? && !blocking_author?
  end

  def destroy?
    staff? || owned?
  end

  alias unreblog? destroy?

  def update?
    staff?
  end

  private

  def direct?
    record.direct_visibility?
  end

  def owned?
    author.id == current_account&.id
  end

  def private?
    record.private_visibility?
  end

  def mention_exists?
    return false if current_account.nil?

    if record.mentions.loaded?
      record.mentions.any? { |mention| mention.account_id == current_account.id }
    else
      record.mentions.where(account: current_account).exists?
    end
  end

  def author_blocking_domain?
    return false if current_account.nil? || current_account.domain.nil?

    author.domain_blocking?(current_account.domain)
  end

  def blocking_author?
    return false if current_account.nil?

    @preloaded_relations[:blocking] ? @preloaded_relations[:blocking][author.id] : current_account.blocking?(author)
  end

  def author_blocking?
    return false if current_account.nil?

    @preloaded_relations[:blocked_by] ? @preloaded_relations[:blocked_by][author.id] : author.blocking?(current_account)
  end

  def following_author?
    return false if current_account.nil?

    @preloaded_relations[:following] ? @preloaded_relations[:following][author.id] : current_account.following?(author)
  end

  def author
    record.account
  end

  def local_only?
    record.local_only?
  end

  def still_accessible?
    return true unless record.local?
    record.updated_at > record.account.user.max_public_access.days.ago
  end

  def author_allows_anon?
    (!current_account.nil? && user_signed_in?) || (!record.account.block_anon && !record.account.hidden)
  end
end
