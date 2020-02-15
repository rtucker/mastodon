# frozen_string_literal: true

class PostStatusService < BaseService
  include Redisable

  MIN_SCHEDULE_OFFSET = 5.minutes.freeze
  MIN_DESTRUCT_OFFSET = 30.seconds.freeze

  VISIBILITY_RANK = {
    'public'    => 0,
    'unlisted'  => 1,
    'local'     => 1,
    'private'   => 2,
    'direct'    => 3,
    'limited'   => 3,
  }

  # Post a text status update, fetch and notify remote users mentioned
  # @param [Account] account Account from which to post
  # @param [Hash] options
  # @option [String] :text Message
  # @option [Status] :thread Optional status to reply to
  # @option [Tag] :tags Optional tags to include
  # @option [Time] :created_at Optional time which status was originally posted
  # @option [Boolean] :sensitive
  # @option [String] :visibility
  # @option [Boolean] :local_only
  # @option [String] :sharekey
  # @option [String] :spoiler_text
  # @option [String] :language
  # @option [String] :scheduled_at
  # @option [String] :delete_after
  # @option [String] :defederate_after
  # @option [Account] :mentions Optional accounts to mention out-of-body
  # @option [Boolean] :noreplies Author does not accept replies
  # @option [Boolean] :nocrawl Optional skip link card generation
  # @option [Boolean] :nomentions Optional skip mention processing
  # @option [Boolean] :delayed Optional publishing delay of 30 secs
  # @option [Hash] :poll Optional poll to attach
  # @option [Enumerable] :media_ids Optional array of media IDs to attach
  # @option [Doorkeeper::Application] :application
  # @option [String] :idempotency Optional idempotency key
  # @return [Status]
  def call(account, options = {})
    @account     = account
    @options     = options
    @text        = @options[:text] || ''
    @footer      = @options[:footer]
    @in_reply_to = @options[:thread]
    @tags        = @options[:tags] || []
    @local_only  = @options[:local_only]
    @sensitive   = (@account.force_sensitive? ? true : @options[:sensitive])

    @preloaded_tags = @options[:preloaded_tags] || []
    @preloaded_mentions = @options[:preloaded_mentions] || []

    @is_delayed = @options[:delayed].present? || @account.user.delayed_roars?
    @delay_for = @is_delayed ? [5, @account.user.delayed_for].max : 1
    @delay_until = Time.now.utc + @delay_for.seconds

    raise Mastodon::LengthValidationError, I18n.t('statuses.replies_rejected') if recipient_rejects_replies?
    raise Mastodon::LengthValidationError, I18n.t('statuses.kicked') if kicked?

    return idempotency_duplicate if idempotency_given? && idempotency_duplicate?

    validate_media!
    preprocess_attributes!

    if scheduled?
      schedule_status!
    else
      return unless process_status!

      opts = {
        visibility: @visibility,
        local_only: @local_only,
        federate: @options[:federate],
        distribute: @options[:distribute],
        nocrawl: @options[:nocrawl],
        reject_replies: @options[:noreplies] || false,
        hidden: false,
      }.compact

      PostStatusWorker.perform_at(@delay_until, @status.id, opts)
      DistributionWorker.perform_async(@status.id, delayed = true) unless @options[:distribute] == false
    end

    redis.setex(idempotency_key, 3_600, @status.id) if idempotency_given?

    @status
  end

  private

  def recipient_rejects_replies?
    @in_reply_to.present? && @in_reply_to.reject_replies && @in_reply_to.account_id != @account.id
  end

  def kicked?
    @in_reply_to.present? && ConversationKick.where(account_id: @account.id, conversation_id: @in_reply_to.conversation_id).exists?
  end

  def mark_recipient_known
    @in_reply_to.account.mark_known! unless !Setting.auto_mark_known || !Setting.mark_known_from_mentions || @in_reply_to.account.known?
  end

  def set_footer_from_i_am
    return if @footer.present? || @options[:no_footer]
    name = @account.user.vars['_they:are']
    return if name.blank?
    @footer = @account.user.vars["_they:are:#{name}"]
  end

  def set_initial_visibility
    @visibility = @options[:visibility] || @account.user_default_visibility
  end

  def limit_visibility_if_silenced
    @visibility = :unlisted if @visibility.in?([nil, 'public', 'local']) && @account.silenced? || @account.force_unlisted
  end

  def limit_visibility_to_reply
    return if @in_reply_to.visibility.nil?

    @visibility = @in_reply_to.visibility if @visibility.nil? ||
      VISIBILITY_RANK[@visibility] < VISIBILITY_RANK[@in_reply_to.visibility]
  end

  def limit_visibility_if_draft
    if @tags.include?('self.draft') || @preloaded_tags.include?('self.draft')
      @visibility = :direct
      @local_only = true
    end
  end

  def unfilter_thread_on_reply
    ConversationKick.where(account_id: @in_reply_to.account_id, conversation: @in_reply_to.conversation_id).destroy_all
  end

  def inherit_reply_rejection
    return unless @in_reply_to.reject_replies && @in_reply_to.account_id == @account.id
    @options[:noreplies] = true
  end

  def set_local_only
    @local_only = true if @account.user_always_local_only? || @in_reply_to&.local_only
  end

  # move tags out of body so we can format them later
  def extract_tags
    return unless '#'.in?(@text)
    @text.gsub!(/^##/, "\ufdd6")
    @text.gsub!('##', "\ufdd9")
    @tags |= Extractor.extract_hashtags(@text)
    @text.strip!
    @text.gsub!(/^(?:#[\w:._·\-]+\s*)+$/, '')
    @text.strip!
    @text.gsub!("\ufdd9", "##")
    @text.gsub!("\ufdd6", "#")
  end

  def protect_leading_spaces
    @text.gsub!(/^ /, "\u200b ")
  end

  def preprocess_attributes!
    if @text.blank? && @options[:spoiler_text].present?
     @text = '.'
     @text = @media.find(&:video?) ? '📹' : '🖼' if @media.size > 0
    end

    @text = @text.dup if @text.frozen?

    set_footer_from_i_am
    extract_tags
    protect_leading_spaces
    set_local_only
    set_initial_visibility
    limit_visibility_if_silenced
    limit_visibility_if_draft

    unless @in_reply_to.nil?
      mark_recipient_known
      inherit_reply_rejection
      limit_visibility_to_reply
      unfilter_thread_on_reply
    end

    @text.freeze

    @sensitive = (@account.user_defaults_to_sensitive? || @options[:spoiler_text].present?) if @sensitive.nil?

    @scheduled_at = @options[:scheduled_at]&.to_datetime
    @scheduled_at = nil if scheduled_in_the_past?

    case @options[:delete_after].class
    when ActiveSupport::Duration
      @delete_after = @options[:delete_after]
    when Integer
      @delete_after = @options[:delete_after].minutes
    when Float
      @delete_after = @options[:delete_after].minutes
    else
      @delete_after = @account.user.roar_lifespan.days unless @account.user.roar_lifespan == 0
    end
    @delete_after = MIN_DESTRUCT_OFFSET if @delete_after.present? && (@delete_after < MIN_DESTRUCT_OFFSET)
    @delete_after += @delay_for.seconds if @delete_after && @is_delayed

    case @options[:defederate_after].class
    when ActiveSupport::Duration
      @defederate_after = @options[:defederate_after]
    when Integer
      @defederate_after = @options[:defederate_after].minutes
    when Float
      @defederate_after = @options[:defederate_after].minutes
    else
      @defederate_after = @account.user.roar_defederate.days unless @account.user.roar_defederate == 0
    end
    @defederate_after = MIN_DESTRUCT_OFFSET if @defederate_after.present? && (@defederate_after < MIN_DESTRUCT_OFFSET)
    @defederate_after += @delay_for.seconds if @defederate_after && @is_delayed
  rescue ArgumentError
    raise ActiveRecord::RecordInvalid
  end

  def process_status!
    # The following transaction block is needed to wrap the UPDATEs to
    # the media attachments when the status is created

    ApplicationRecord.transaction do
      @status = @account.statuses.create!(status_attributes)
    end

    return false if @status.destroyed?

    set_expirations
    process_hashtags_service.call(@status, @tags, @preloaded_tags)
    process_mentions
    true
  end

  def schedule_status!
    status_for_validation = @account.statuses.build(status_attributes)

    if status_for_validation.valid?
      status_for_validation.destroy

      # The following transaction block is needed to wrap the UPDATEs to
      # the media attachments when the scheduled status is created

      ApplicationRecord.transaction do
        @status = @account.scheduled_statuses.create!(scheduled_status_attributes)
      end
    else
      raise ActiveRecord::RecordInvalid
    end
  end

  def postprocess_status!
    LinkCrawlWorker.perform_async(@status.id) unless @status.spoiler_text?
    DistributionWorker.perform_async(@status.id)
    ActivityPub::DistributionWorker.perform_async(@status.id) unless @status.local_only?
    PollExpirationNotifyWorker.perform_at(@status.poll.expires_at, @status.poll.id) if @status.poll
  end

  def validate_media!
    return if @options[:media_ids].blank? || !@options[:media_ids].is_a?(Enumerable)

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.too_many') if @options[:media_ids].size > 6 || @options[:poll].present?

    @media = @account.media_attachments.where(status_id: nil).where(id: @options[:media_ids].take(6).map(&:to_i))

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.images_and_video') if @media.size > 1 && @media.find(&:video?)
  end

  def process_mentions
    if @options[:mentions].present?
      @options[:mentions].each do |mentioned_account|
        mentioned_account.mentions.where(status: @status).first_or_create(status: @status)
      end
    end

    process_mentions_service.call(@status, skip_notify: true) unless @options[:nomentions]
  end

  def language_from_option(str)
    ISO_639.find(str)&.alpha2
  end

  def set_expirations
    return if @status.no_clobber_expirations?
    @status.delete_after = @delete_after if @delete_after && @status.delete_after.nil?
    @status.defederate_after = @defederate_after if @defederate_after && @status.defederate_after.nil?
  end

  def process_hashtags_service
    ProcessHashtagsService.new
  end

  def process_mentions_service
    ProcessMentionsService.new
  end

  def scheduled?
    @scheduled_at.present?
  end

  def idempotency_key
    "idempotency:status:#{@account.id}:#{@options[:idempotency]}"
  end

  def idempotency_given?
    @options[:idempotency].present?
  end

  def idempotency_duplicate
    if scheduled?
      @account.schedule_statuses.find(@idempotency_duplicate)
    else
      @account.statuses.find(@idempotency_duplicate)
    end
  end

  def idempotency_duplicate?
    @idempotency_duplicate = redis.get(idempotency_key)
  end

  def scheduled_in_the_past?
    @scheduled_at.present? && @scheduled_at <= Time.now.utc + MIN_SCHEDULE_OFFSET
  end

  def status_attributes
    {
      created_at: @options[:created_at] ? @options[:created_at].to_datetime.utc : Time.now.utc,
      text: @text,
      footer: @footer,
      media_attachments: @media || [],
      thread: @in_reply_to,
      poll_attributes: poll_attributes,
      sensitive: @sensitive,
      spoiler_text: @options[:spoiler_text] || '',
      visibility: @visibility,
      local_only: @local_only,
      reject_replies: @options[:noreplies] || false,
      sharekey: @options[:sharekey],
      language: language_from_option(@options[:language]) || @account.user_default_language&.presence || 'en',
      application: @options[:application],
      content_type: @options[:content_type] || @account.user&.setting_default_content_type,
      hidden: true,
    }.compact
  end

  def scheduled_status_attributes
    {
      scheduled_at: @scheduled_at,
      media_attachments: @media || [],
      params: scheduled_options,
    }
  end

  def poll_attributes
    return if @options[:poll].blank?

    @options[:poll].merge(account: @account)
  end

  def scheduled_options
    @options.tap do |options_hash|
      options_hash[:in_reply_to_id] = options_hash.delete(:thread)&.id
      options_hash[:application_id] = options_hash.delete(:application)&.id
      options_hash[:scheduled_at]   = nil
      options_hash[:idempotency]    = nil
    end
  end
end
