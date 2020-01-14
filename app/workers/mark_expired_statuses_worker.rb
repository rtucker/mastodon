# frozen_string_literal: true

class MarkExpiredStatusesWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'bulk'

  def perform(account_id)
    @account = Account.find(account_id)
    return if @account&.user.nil?

    @roar_defederate = @account.user.roar_defederate
    @roar_lifespan = @account.user.roar_lifespan

    defederate = @account.user.roar_defederate_old && @roar_defederate != 0
    lifespan = @account.user.roar_lifespan_old && @roar_lifespan != 0

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

    UserSettingsDecorator.new(@account.user).update({
      'setting_roar_defederate_old' => false,
      'setting_roar_lifespan_old' => false,
    })
  rescue ActiveRecord::RecordNotFound
    true
  end
end
