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

    raise Mastodon::LengthValidationError, I18n.t('statuses.replies_rejected') if recipient_rejects_replies?

    return idempotency_duplicate if idempotency_given? && idempotency_duplicate?

    validate_media!
    preprocess_attributes!

    if scheduled?
      schedule_status!
    else
      return unless process_status!
      if @options[:delayed].present? || @account&.user&.delayed_roars?
        delay_for = [5, @account&.user&.delayed_for.to_i].max
        delay_until = Time.now.utc + delay_for.seconds
        opts = {
          visibility: @visibility,
          local_only: @local_only,
          federate: @options[:federate],
          distribute: @options[:distribute],
          nocrawl: @options[:nocrawl],
          nomentions: @options[:nomentions],
          delete_after: @delete_after.nil? ? nil : @delete_after + 1.minute,
          reject_replies: @options[:noreplies] || false,
        }.compact

        PostStatusWorker.perform_at(delay_until, @status.id, opts)
        DistributionWorker.perform_async(@status.id, delayed = true) unless @options[:distribute] == false
      else
        postprocess_status!
        bump_potential_friendship!
      end
    end

    redis.setex(idempotency_key, 3_600, @status.id) if idempotency_given?

    @status
  end

  private

  def recipient_rejects_replies?
    @in_reply_to.present? && @in_reply_to.reject_replies && @in_reply_to.account_id != @account.id
  end

  def mark_recipient_known
    @in_reply_to.account.mark_known! unless @in_reply_to.account.known?
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
    @visibility = :unlisted if @visibility.in?([nil, 'public']) && @account.silenced? || @account.force_unlisted
  end

  def limit_visibility_to_reply
    @visibility = @in_reply_to.visibility if @visibility.nil? ||
      VISIBILITY_RANK[@visibility] < VISIBILITY_RANK[@in_reply_to.visibility]
  end

  def unfilter_thread_on_reply
    Redis.current.srem("filtered_threads:#{@account.id}", @in_reply_to.conversation_id)
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
    @text = @text.dup if @text.frozen?
    @text.gsub!(/^##/, "\uf666")
    @text.gsub!('##', "\uf669")
    @tags |= Extractor.extract_hashtags(@text)
    @text.strip!
    @text.gsub!(/^(?:#[\w:._·\-]+\s*)+$/, '')
    @text.strip!
    @text.gsub!("\uf669", "##")
    @text.gsub!("\uf666", "#")
  end

  def preprocess_attributes!
    if @text.blank? && @options[:spoiler_text].present?
     @text = '.'
     @text = @media.find(&:video?) ? '📹' : '🖼' if @media.size > 0
    end

    set_footer_from_i_am
    extract_tags
    set_local_only
    set_initial_visibility
    limit_visibility_if_silenced

    unless @in_reply_to.nil?
      mark_recipient_known
      inherit_reply_rejection
      limit_visibility_to_reply
      unfilter_thread_on_reply
    end

    @sensitive = (@account.user_defaults_to_sensitive? || @options[:spoiler_text].present?) if @sensitive.nil?

    @scheduled_at = @options[:scheduled_at]&.to_datetime
    @scheduled_at = nil if scheduled_in_the_past?

    case @options[:delete_after].class
    when NilClass
      @delete_after = @account.user.setting_roar_lifespan.to_i.days
    when ActiveSupport::Duration
      @delete_after = @options[:delete_after]
    when Integer
      @delete_after = @options[:delete_after].minutes
    when Float
      @delete_after = @options[:delete_after].minutes
    end
    @delete_after = nil if @delete_after.present? && (@delete_after < MIN_DESTRUCT_OFFSET)

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

    process_hashtags_service.call(@status, @tags, @preloaded_tags)
    process_mentions_service.call(@status) unless @options[:delayed].present? || @options[:nomentions]

    return true
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
    LinkCrawlWorker.perform_async(@status.id) unless @options[:nocrawl] || @status.spoiler_text?
    DistributionWorker.perform_async(@status.id) unless @options[:distribute] == false

    unless @status.local_only? || @options[:distribute] == false || @options[:federate] == false
      ActivityPub::DistributionWorker.perform_async(@status.id)
    end

    PollExpirationNotifyWorker.perform_at(@status.poll.expires_at, @status.poll.id) if @status.poll

    @status.delete_after = @delete_after unless @delete_after.nil?
  end

  def validate_media!
    return if @options[:media_ids].blank? || !@options[:media_ids].is_a?(Enumerable)

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.too_many') if @options[:media_ids].size > 6 || @options[:poll].present?

    @media = @account.media_attachments.where(status_id: nil).where(id: @options[:media_ids].take(6).map(&:to_i))

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.images_and_video') if @media.size > 1 && @media.find(&:video?)
  end

  def language_from_option(str)
    ISO_639.find(str)&.alpha2
  end

  def process_mentions_service
    ProcessMentionsService.new
  end

  def process_hashtags_service
    ProcessHashtagsService.new
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

  def bump_potential_friendship!
    return if !@status.reply? || @account.id == @status.in_reply_to_account_id
    ActivityTracker.increment('activity:interactions')
    return if @account.following?(@status.in_reply_to_account_id)
    PotentialFriendshipTracker.record(@account.id, @status.in_reply_to_account_id, :reply)
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
      delete_after: @delete_after,
      reject_replies: @options[:noreplies] || false,
      sharekey: @sharekey,
      language: language_from_option(@options[:language]) || @account.user_default_language&.presence || 'en',
      application: @options[:application],
      content_type: @options[:content_type] || @account.user&.setting_default_content_type,
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
