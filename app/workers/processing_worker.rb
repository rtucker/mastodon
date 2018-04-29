# frozen_string_literal: true

class ProcessingWorker
  include Sidekiq::Worker

  sidekiq_options backtrace: true

  def perform(account_id, body)
    @account = Account.find(account_id)
    @body = body

    process
  rescue => e
    raise e.class, "Processing feed failed for #{@account.uri}: #{e.message}", e.backtrace[0]
  end

  private

  def process
    light = Stoplight(@account.domain) do
      ProcessFeedService.new.call(@body, @account, override_timestamps: true)
    end

    light.run
  end
end
