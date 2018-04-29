# frozen_string_literal: true

class ProcessingWorker
  include Sidekiq::Worker

  sidekiq_options backtrace: true

  def perform(account_id, body)
    @account = Account.find(account_id)
    @body = body

    process_feed
  end

  private

  def process_feed
    light = Stoplight(@account.domain) do
      ProcessFeedService.new.call(@body, @account, override_timestamps: true)
    end

    light.run
  end
end
