# frozen_string_literal: true

class ResolveAccountWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', unique: :until_executed

  def perform(uri)
    @username, @domain = uri.split('@')
    @uri = uri

    process
  rescue => e
    raise e.class, "Resolving account failed for #{uri}: #{e.message}", e.backtrace[0]
  end

  private

  def process
    light = Stoplight(@domain) do
      ResolveAccountService.new.call(@uri)
    end

    light.run
  end
end
