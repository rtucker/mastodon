# frozen_string_literal: true

class LogWorker
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed

  def perform(log_text, subject: nil, markdown: false, scope: nil)
    logger_id = ENV['LOG_USER'].to_i
    return true if logger_id == 0

    logger = Account.find_by(id: logger_id)
    return true if logger.nil?

    scope_prefix = ENV.fetch('LOG_SCOPE_PREFIX', 'admin.log')
    tag = scope.nil? ? scope_prefix : "#{scope_prefix}.#{scope}"
    if subject.nil? && log_text.match?(/comments?:/i)
      subject = 'This admin action may contain sensitive content.'
    end

    PostStatusService.new.call(
      logger,
      spoiler_text: subject,
      created_at: Time.now.utc,
      text: log_text.strip,
      tags: [tag],
      visibility: :unlisted,
      local_only: true,
      content_type: markdown ? 'text/markdown' : 'text/plain',
      language: 'en',
      nocrawl: true,
      nomentions: true,
    )
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    true
  end
end
