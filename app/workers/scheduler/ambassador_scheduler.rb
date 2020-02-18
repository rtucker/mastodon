# frozen_string_literal: true

class Scheduler::AmbassadorScheduler
  include Sidekiq::Worker

  def perform
    @ambassador = find_ambassador_acct
    return if @ambassador.nil?

    status = next_boost
    return if status.nil?

    ReblogStatusWorker.perform_async(@ambassador.id, status.id)
  end

  private

  def find_ambassador_acct
    ambassador = ENV['AMBASSADOR_USER'].to_i
    return if ambassador.zero?
    Account.find_by(id: ambassador)
  end

  def next_boost
    ambassador_boost_candidates.first
  end

  def ambassador_boost_candidates
    ambassador_boostable.joins(:status_stat).where('favourites_count + reblogs_count > 4')
  end

  def ambassador_boostable
    query = ambassador_unboosted.excluding_silenced_accounts.not_excluded_by_account(@ambassador)

    unless !@ambassador.user.filters_enabled || @ambassador.custom_filters.enabled.blank?
      if @ambassador.user.invert_filters
        query = query.search_filtered_by_account(@ambassador.id)
      else
        query = query.search_not_filtered_by_account(@ambassador.id)
      end
    end

    query
  end

  def ambassador_unboosted
    locally_boostable.where.not(id: ambassador_boosts)
  end

  def ambassador_boosts
    @ambassador.statuses.reblogs.reorder(nil).select(:reblog_of_id)
  end

  def locally_boostable
    Status.local.without_reblogs.without_replies.public_local_visibility
  end
end
