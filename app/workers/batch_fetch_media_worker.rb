# frozen_string_literal: true

class BatchFetchMediaWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'bulk', retry: 2

  def perform(media_attachment_ids)
    media_attachment_ids.each_with_index do |attachment_id, index|
      FetchMediaWorker.perform_async(attachment_id)
      sleep(0.5 * Sidekiq::Queue.new(:bulk).size)
    end
  end
end
