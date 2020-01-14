# frozen_string_literal: true

class MarkExpiredStatusesWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'bulk'

  def perform(account_id, defederate = false, lifespan = false)
    @account = Account.find(account_id)
    return if @account&.user.nil?
    @user = @account.user

    @roar_defederate = @user.roar_defederate.to_i
    @roar_lifespan = @user.roar_lifespan.to_i

    defederate = false if @roar_defederate == 0
    lifespan = false if @roar_lifespan == 0

    return unless defederate || lifespan

    offset = 30.minutes

    @account.statuses.find_each do |status|
      modified = false

      if defederate && !status.local_only? && status.updated_at < @roar_defederate.days.ago
        status.defederate_after = offset
        modified = true
      end

      if lifespan && status.updated_at < @roar_lifespan.days.ago
        status.delete_after = offset + 30.minutes
        modified = true
      end

      if modified
        Rails.cache.delete("statuses/#{status.id}")
        offset += 1.second
      end
    end
  rescue ActiveRecord::RecordNotFound
    true
  end
end
