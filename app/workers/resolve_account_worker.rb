# frozen_string_literal: true

class ResolveAccountWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', unique: :until_executed

  def perform(uri)
    @username, @domain = uri.split('@')
    @uri = uri

    process_resolve
  end

  private

  def process_resolve
    light = Stoplight(@domain) do
      ResolveAccountService.new.call(@uri)
    end

    light.run
  end
end
