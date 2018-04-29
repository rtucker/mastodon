# frozen_string_literal: true

class NotificationWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'push', retry: 5

  def perform(xml, source_account_id, target_account_id)
    @xml = xml
    @source_account = Account.find(source_account_id)
    @target_account = Account.find(target_account_id)

    process
  rescue => e
    raise e.class, "Notification failed for #{@source_account.uri} to #{@target_account.uri}: #{e.message}", e.backtrace[0]
  end

  private

  def process
    light = Stoplight(@target_account.domain) do
      SendInteractionService.new.call(@xml, @source_account, @target_account)
    end

    light.run
  end
end
