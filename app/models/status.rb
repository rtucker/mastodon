# frozen_string_literal: true
# == Schema Information
#
# Table name: statuses
#
#  id                     :bigint(8)        not null, primary key
#  uri                    :string
#  text                   :text             default(""), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  in_reply_to_id         :bigint(8)
#  reblog_of_id           :bigint(8)
#  url                    :string
#  sensitive              :boolean          default(FALSE), not null
#  visibility             :integer          default("public"), not null
#  spoiler_text           :text             default(""), not null
#  reply                  :boolean          default(FALSE), not null
#  language               :string
#  conversation_id        :bigint(8)
#  local                  :boolean
#  account_id             :bigint(8)        not null
#  application_id         :bigint(8)
#  in_reply_to_account_id :bigint(8)
#  local_only             :boolean
#  poll_id                :bigint(8)
#  content_type           :string
#  tsv                    :tsvector
#  curated                :boolean
#  sharekey               :string
#  network                :boolean
#

class Status < ApplicationRecord
  before_destroy :unlink_from_conversations

  include Paginable
  include Streamable
  include Cacheable
  include StatusThreadingConcern

  LOCAL_DOMAINS = ENV.fetch('LOCAL_DOMAINS', '').chomp.split(/\.?\s+/).freeze
  FORCE_SENSITIVE = ENV.fetch('FORCE_SENSITIVE', '').chomp.split(/\.?\s+/).freeze
  FORCE_UNLISTED = ENV.fetch('FORCE_UNLISTED', '').chomp.split(/\.?\s+/).freeze

  # If `override_timestamps` is set at creation time, Snowflake ID creation
  # will be based on current time instead of `created_at`
  attr_accessor :override_timestamps

  update_index('statuses#status', :proper) if Chewy.enabled?

  enum visibility: [:public, :unlisted, :private, :direct, :limited], _suffix: :visibility

  belongs_to :application, class_name: 'Doorkeeper::Application', optional: true

  belongs_to :account, inverse_of: :statuses
  belongs_to :in_reply_to_account, foreign_key: 'in_reply_to_account_id', class_name: 'Account', optional: true
  belongs_to :conversation, optional: true
  belongs_to :preloadable_poll, class_name: 'Poll', foreign_key: 'poll_id', optional: true

  belongs_to :thread, foreign_key: 'in_reply_to_id', class_name: 'Status', inverse_of: :replies, optional: true
  belongs_to :reblog, foreign_key: 'reblog_of_id', class_name: 'Status', inverse_of: :reblogs, optional: true

  has_many :favourites, inverse_of: :status, dependent: :destroy
  has_many :bookmarks, inverse_of: :status, dependent: :destroy
  has_many :reblogs, foreign_key: 'reblog_of_id', class_name: 'Status', inverse_of: :reblog, dependent: :destroy
  has_many :replies, foreign_key: 'in_reply_to_id', class_name: 'Status', inverse_of: :thread
  has_many :mentions, dependent: :destroy, inverse_of: :status
  has_many :active_mentions, -> { active }, class_name: 'Mention', inverse_of: :status
  has_many :media_attachments, dependent: :nullify

  has_and_belongs_to_many :tags
  has_and_belongs_to_many :preview_cards

  has_one :notification, as: :activity, dependent: :destroy
  has_one :stream_entry, as: :activity, inverse_of: :status
  has_one :status_stat, inverse_of: :status
  has_one :poll, inverse_of: :status, dependent: :destroy

  validates :uri, uniqueness: true, presence: true, unless: :local?
  validates :text, presence: true, unless: -> { with_media? || reblog? }
  validates_with StatusLengthValidator
  validates_with DisallowedHashtagsValidator
  validates :reblog, uniqueness: { scope: :account }, if: :reblog?
  validates :visibility, exclusion: { in: %w(direct limited) }, if: :reblog?
  validates :content_type, inclusion: { in: %w(text/plain text/markdown text/html) }, allow_nil: true

  accepts_nested_attributes_for :poll

  default_scope { recent }

  scope :recent, -> { reorder(id: :desc) }
  scope :remote, -> { where(local: false).or(where.not(uri: nil)) }
  scope :local,  -> { where(local: true).or(where(uri: nil)) }
  scope :network, -> { where(network: true) }
  scope :curated, -> { where(curated: true) }

  scope :without_replies, -> { where('statuses.reply = FALSE OR statuses.in_reply_to_account_id = statuses.account_id') }
  scope :without_reblogs, -> { where('statuses.reblog_of_id IS NULL') }
  scope :reblogs, -> { where('statuses.reblog_of_id IS NOT NULL') } # all reblogs
  scope :with_public_visibility, -> { where(visibility: :public) }
  scope :public_browsable, -> { where(visibility: [:public, :unlisted]) }
  scope :tagged_with, ->(tag) { joins(:statuses_tags).where(statuses_tags: { tag_id: tag }) }
  scope :excluding_silenced_accounts, -> { left_outer_joins(:account).where(accounts: { silenced_at: nil }) }
  scope :including_silenced_accounts, -> { left_outer_joins(:account).where.not(accounts: { silenced_at: nil }) }
  scope :not_excluded_by_account, ->(account) { where.not(account_id: account.excluded_from_timeline_account_ids) }
  scope :reply_not_excluded_by_account, ->(account) { where('statuses.in_reply_to_account_id IS NULL OR statuses.in_reply_to_account_id NOT IN (?)', account.excluded_from_timeline_account_ids) }
  scope :mention_not_excluded_by_account, ->(account) { left_outer_joins(:mentions).where('mentions.account_id IS NULL OR mentions.account_id NOT IN (?)', account.excluded_from_timeline_account_ids) }
  scope :not_domain_blocked_by_account, ->(account) { account.excluded_from_timeline_domains.blank? ? left_outer_joins(:account) : left_outer_joins(:account).where('accounts.domain IS NULL OR accounts.domain NOT IN (?)', account.excluded_from_timeline_domains) }
  scope :tagged_with_all, ->(tags) {
    Array(tags).map(&:id).map(&:to_i).reduce(self) do |result, id|
      result.joins("INNER JOIN statuses_tags t#{id} ON t#{id}.status_id = statuses.id AND t#{id}.tag_id = #{id}")
    end
  }
  scope :tagged_with_none, ->(tags) {
    Array(tags).map(&:id).map(&:to_i).reduce(self) do |result, id|
      result.joins("LEFT OUTER JOIN statuses_tags t#{id} ON t#{id}.status_id = statuses.id AND t#{id}.tag_id = #{id}")
            .where("t#{id}.tag_id IS NULL")
    end
  }

  scope :not_local_only, -> { where(local_only: [false, nil]) }

  cache_associated :application,
                   :media_attachments,
                   :conversation,
                   :status_stat,
                   :tags,
                   :preview_cards,
                   :stream_entry,
                   :preloadable_poll,
                   account: :account_stat,
                   active_mentions: { account: :account_stat },
                   reblog: [
                     :application,
                     :stream_entry,
                     :tags,
                     :preview_cards,
                     :media_attachments,
                     :conversation,
                     :status_stat,
                     :preloadable_poll,
                     account: :account_stat,
                     active_mentions: { account: :account_stat },
                   ],
                   thread: { account: :account_stat }

  delegate :domain, to: :account, prefix: true

  REAL_TIME_WINDOW = 6.hours

  def searchable_by(preloaded = nil)
    ids = [account_id]

    if preloaded.nil?
      ids += mentions.pluck(:account_id)
      ids += favourites.pluck(:account_id)
      ids += bookmarks.pluck(:account_id)
      ids += reblogs.pluck(:account_id)
    else
      ids += preloaded.mentions[id] || []
      ids += preloaded.favourites[id] || []
      ids += preloaded.bookmarks[id] || []
      ids += preloaded.reblogs[id] || []
    end

    ids.uniq
  end

  def reply?
    !in_reply_to_id.nil? || attributes['reply']
  end

  def local?
    attributes['local'] || uri.nil?
  end

  def network?
    attributes['network'] || local? || account.domain.in?(LOCAL_DOMAINS)
  end

  def relayed?
    account.username == 'relay' && account.actor_type.in?(Set[:Application, :Service])
  end

  def reblog?
    !reblog_of_id.nil?
  end

  def within_realtime_window?
    created_at >= REAL_TIME_WINDOW.ago
  end

  def verb
    if destroyed?
      :delete
    else
      reblog? ? :share : :post
    end
  end

  def object_type
    reply? ? :comment : :note
  end

  def proper
    reblog? ? reblog : self
  end

  def content
    proper.text
  end

  def target
    reblog
  end

  def preview_card
    preview_cards.first
  end

  def title
    if destroyed?
      "#{account.acct} deleted status"
    else
      reblog? ? "#{account.acct} shared a status by #{reblog.account.acct}" : "New status by #{account.acct}"
    end
  end

  def hidden?
    private_visibility? || direct_visibility? || limited_visibility?
  end

  def distributable?
    public_visibility? || unlisted_visibility?
  end

  def with_media?
    media_attachments.any?
  end

  def non_sensitive_with_media?
    !sensitive? && with_media?
  end

  def emojis
    return @emojis if defined?(@emojis)

    fields  = [spoiler_text, text]
    fields += preloadable_poll.options unless preloadable_poll.nil?

    @emojis = CustomEmoji.from_text(fields.join(' '), account.domain)
  end

  def mark_for_mass_destruction!
    @marked_for_mass_destruction = true
  end

  def marked_for_mass_destruction?
    @marked_for_mass_destruction
  end

  def replies_count
    status_stat&.replies_count || 0
  end

  def reblogs_count
    status_stat&.reblogs_count || 0
  end

  def favourites_count
    status_stat&.favourites_count || 0
  end

  def increment_count!(key)
    update_status_stat!(key => public_send(key) + 1)
  end

  def decrement_count!(key)
    update_status_stat!(key => [public_send(key) - 1, 0].max)
  end

  after_create_commit  :increment_counter_caches
  after_destroy_commit :decrement_counter_caches

  after_create_commit :store_uri, if: :local?
  after_create_commit :update_statistics, if: :local?

  around_create Mastodon::Snowflake::Callbacks

  before_create :set_locality

  before_validation :prepare_contents, if: :local?
  before_validation :set_reblog
  before_validation :set_visibility
  before_validation :set_conversation
  before_validation :set_local

  after_create :set_poll_id
  after_create :process_bangtags, if: :local?

  class << self
    def search_for(term, limit = 66, account = nil)
      pattern = sanitize_sql_like(term)
      pattern = "#{pattern}"
      scope = Status.where("tsv @@ plainto_tsquery('english', ?)", pattern)
      query = scope.where(visibility: :public)
      if account.present?
        query = query
          .or(scope.where(account: account))
          .or(scope.where(account: account.following, visibility: [:private, :unlisted]))
          .or(scope.where(id: account.mentions.select(:status_id)))
      end
      query = query.where(reblog_of_id: nil).limit(limit)
      apply_timeline_filters(query, account, true)
    end

    def selectable_visibilities
      visibilities.keys - %w(direct limited)
    end

    def in_chosen_languages(account)
      where(language: nil).or where(language: account.chosen_languages)
    end

    def as_home_timeline(account)
      where(account: [account] + account.following).where(visibility: [:public, :unlisted, :private])
    end

    def as_direct_timeline(account, limit = 20, max_id = nil, since_id = nil, cache_ids = false)
      # direct timeline is mix of direct message from_me and to_me.
      # 2 queries are executed with pagination.
      # constant expression using arel_table is required for partial index

      # _from_me part does not require any timeline filters
      query_from_me = where(account_id: account.id)
                      .where(Status.arel_table[:visibility].eq(3))
                      .limit(limit)
                      .order('statuses.id DESC')

      # _to_me part requires mute and block filter.
      # FIXME: may we check mutes.hide_notifications?
      query_to_me = Status
                    .joins(:mentions)
                    .merge(Mention.where(account_id: account.id))
                    .where(Status.arel_table[:visibility].eq(3))
                    .limit(limit)
                    .order('mentions.status_id DESC')
                    .not_excluded_by_account(account)

      if max_id.present?
        query_from_me = query_from_me.where('statuses.id < ?', max_id)
        query_to_me = query_to_me.where('mentions.status_id < ?', max_id)
      end

      if since_id.present?
        query_from_me = query_from_me.where('statuses.id > ?', since_id)
        query_to_me = query_to_me.where('mentions.status_id > ?', since_id)
      end

      if cache_ids
        # returns array of cache_ids object that have id and updated_at
        (query_from_me.cache_ids.to_a + query_to_me.cache_ids.to_a).uniq(&:id).sort_by(&:id).reverse.take(limit)
      else
        # returns ActiveRecord.Relation
        items = (query_from_me.select(:id).to_a + query_to_me.select(:id).to_a).uniq(&:id).sort_by(&:id).reverse.take(limit)
        Status.where(id: items.map(&:id))
      end
    end

    def as_public_timeline(account = nil, local_only = false)
      if local_only
        query = Status.network
          .with_public_visibility
          .without_replies
          .without_reblogs
      elsif account.nil? || account&.user&.setting_rawr_federated
        query = timeline_scope(local_only)
        query = query.without_replies unless Setting.show_replies_in_public_timelines
      else
        scope = Status.curated
        scope = scope.without_replies unless Setting.show_replies_in_public_timelines
        query = scope.public_browsable
          .or(scope.where(account: account.following, visibility: :private))
      end

      apply_timeline_filters(query, account, local_only)
    end

    def as_tag_timeline(tag, account = nil, local_only = false)
      query = browsable_timeline_scope(local_only).tagged_with(tag)
      apply_timeline_filters(query, account, local_only)
    end

    def as_outbox_timeline(account)
      where(account: account, visibility: :public)
    end

    def favourites_map(status_ids, account_id)
      Favourite.select('status_id').where(status_id: status_ids).where(account_id: account_id).each_with_object({}) { |f, h| h[f.status_id] = true }
    end

    def bookmarks_map(status_ids, account_id)
      Bookmark.select('status_id').where(status_id: status_ids).where(account_id: account_id).map { |f| [f.status_id, true] }.to_h
    end

    def reblogs_map(status_ids, account_id)
      select('reblog_of_id').where(reblog_of_id: status_ids).where(account_id: account_id).reorder(nil).each_with_object({}) { |s, h| h[s.reblog_of_id] = true }
    end

    def mutes_map(conversation_ids, account_id)
      ConversationMute.select('conversation_id').where(conversation_id: conversation_ids).where(account_id: account_id).each_with_object({}) { |m, h| h[m.conversation_id] = true }
    end

    def pins_map(status_ids, account_id)
      StatusPin.select('status_id').where(status_id: status_ids).where(account_id: account_id).each_with_object({}) { |p, h| h[p.status_id] = true }
    end

    def reload_stale_associations!(cached_items)
      account_ids = []

      cached_items.each do |item|
        account_ids << item.account_id
        account_ids << item.reblog.account_id if item.reblog?
      end

      account_ids.uniq!

      return if account_ids.empty?

      accounts = Account.where(id: account_ids).includes(:account_stat).each_with_object({}) { |a, h| h[a.id] = a }

      cached_items.each do |item|
        item.account = accounts[item.account_id]
        item.reblog.account = accounts[item.reblog.account_id] if item.reblog?
      end
    end

    def permitted_for(target_account, account)
      visibility = [:public, :unlisted]

      if account.nil?
        where(visibility: visibility).not_local_only
      elsif target_account.blocking?(account) # get rid of blocked peeps
        none
      elsif account.id == target_account.id # author can see own stuff
        all
      else
        # followers can see followers-only stuff, but also things they are mentioned in.
        # non-followers can see everything that isn't private/direct, but can see stuff they are mentioned in.
        scope = left_outer_joins(:reblog)

        query = scope.where(visibility: visibility).or(scope.where(id: account.mentions.select(:status_id)))
        if account.following?(target_account) then
          query = query.or(scope.where(visibility: :private).without_replies)
        end
        query.merge(scope.where(reblog_of_id: nil).or(scope.where.not(reblogs_statuses: { account_id: account.excluded_from_timeline_account_ids })))
      end
    end

    private

    def timeline_scope(local_only = false)
      starting_scope = local_only ? Status.network : Status
      starting_scope = starting_scope.with_public_visibility
      if Setting.show_reblogs_in_public_timelines
        starting_scope
      else
        starting_scope.without_reblogs
      end
    end

    def browsable_timeline_scope(local_only = false)
      starting_scope = local_only ? Status.network : Status
      starting_scope
        .public_browsable
        .without_reblogs
    end

    def apply_timeline_filters(query, account, local_only)
      if account.nil?
        filter_timeline_default(query)
      else
        filter_timeline_for_account(query, account, local_only)
      end
    end

    def filter_timeline_for_account(query, account, local_only)
      query = query.not_excluded_by_account(account)
      query = query.not_domain_blocked_by_account(account) unless local_only
      query = query.in_chosen_languages(account) if account.chosen_languages.present?
      query = query.reply_not_excluded_by_account(account)
      query = query.mention_not_excluded_by_account(account)
      query.merge(account_silencing_filter(account))
    end

    def filter_timeline_default(query)
      query.not_local_only.excluding_silenced_accounts
    end

    def account_silencing_filter(account)
      if account.silenced?
        including_myself = left_outer_joins(:account).where(account_id: account.id).references(:accounts)
        excluding_silenced_accounts.or(including_myself)
      else
        excluding_silenced_accounts
      end
    end
  end

  def marked_local_only?
    # match both with and without U+FE0F (the emoji variation selector)
    /(?:#!|\u{1f441}\ufe0f?)\u200b?\z/.match?(content)
  end

  def marked_no_replies?
    /(:ms_dont_at_me:|(don't|do not|no) ((at|@|mention) me)|reply|replies)/.match?(spoiler_text)
  end

  private

  def update_status_stat!(attrs)
    return if marked_for_destruction? || destroyed?

    record = status_stat || build_status_stat
    record.update(attrs)
  end

  def store_uri
    update_column(:uri, ActivityPub::TagManager.instance.uri_for(self)) if uri.nil?
  end

  def prepare_contents
    text&.strip!
    spoiler_text&.strip!
  end

  def set_reblog
    self.reblog = reblog.reblog if reblog? && reblog.reblog?
  end

  def set_poll_id
    update_column(:poll_id, poll.id) unless poll.nil?
  end

  def set_visibility
    self.visibility = reblog.visibility if reblog? && visibility.nil?
    self.visibility = (account.locked? ? :private : :public) if visibility.nil?
    self.visibility = :unlisted if visibility == :public && account.domain.in?(FORCE_UNLISTED)
    self.sensitive  = true if account.domain.in?(FORCE_SENSITIVE)
    self.sensitive  = false if sensitive.nil?
  end

  def set_locality
    if account.domain.nil? && !attribute_changed?(:local_only)
      self.local_only = marked_local_only?
      self.local_only ||= account.user.setting_always_local
      self.local_only ||= reply? && Status.where(id: in_reply_to_id, local_only: true).exists?
    end
  end

  def process_bangtags
    return if text&.nil?
    return unless '#!'.in?(text)
    text.gsub!('#!!', "#\u200c!")

    prefix_ns = {
      'permalink' => ['link'],
      'cloudroot' => ['link'],
      'blogroot' => ['link'],
    }

    aliases = {
      ['media', 'end'] => ['var', 'end'],
      ['media', 'stop'] => ['var', 'end'],
      ['media', 'endall'] => ['var', 'endall'],
      ['media', 'stopall'] => ['var', 'endall'],
    }

    # sections of the final status text
    chunks = []
    # list of transformation commands
    tf_cmds = []
    # list of post-processing commands
    post_cmds = []
    # hash of bangtag variables
    vars = {}
    # keep track of what variables we're appending the value of between chunks
    vore_stack = []
    # keep track of what type of nested components are active so we can !end them in order
    component_stack = []

    text.split(/(#!(?:.*:!#|{.*?}|[^\s#]+))/).each do |chunk|
      if chunk.starts_with?("#!")
        chunk.sub!(/(\\:)?+:+?!#\Z/, '\1')
        chunk.sub!(/{(.*)}\Z/, '\1')

        if vore_stack.last != '_comment'
          cmd = chunk[2..-1].strip
          next if cmd.blank?
          cmd = cmd.split(':::')
          cmd = cmd[0].split('::') + cmd[1..-1]
          cmd = cmd[0].split(':') + cmd[1..-1]

          cmd.map! {|c| c.gsub(/\\:/, ':').gsub(/\\\\:/, '\:')}

          prefix = prefix_ns[cmd[0]]
          cmd = prefix + cmd unless prefix.nil?

          aliases.each_key do |old_cmd|
            cmd = aliases[old_cmd] + cmd.drop(old_cmd.length) if cmd.take(old_cmd.length) == old_cmd
          end
        elsif chunk.in?(['#!comment:end', '#!comment:stop', '#!comment:endall', '#!comment:stopall'])
          vore_stack.pop
          component_stack.pop
          next
        else
          next
        end

        case cmd[0]
        when 'var'
          chunk = nil
          case cmd[1]
          when 'end', 'stop'
            vore_stack.pop
            component_stack.pop
          when 'endall', 'stopall'
            vore_stack = []
            component_stack.reject! {|c| c == :var}
          else
            var = cmd[1]
            next if var.nil? || var.starts_with?('_')
            new_value = cmd[2..-1]
            if new_value.blank?
              chunk = vars[var]
            elsif new_value.length == 1 && new_value[0] == '-'
              vore_stack.push(var)
              component_stack.push(:var)
            else
              vars[var] = new_value.join(':')
            end
          end
        when 'tf'
          chunk = nil
          case cmd[1]
          when 'end', 'stop'
            tf_cmds.pop
            component_stack.pop
          when 'endall', 'stopall'
            tf_cmds = []
            component_stack.reject! {|c| c == :tf}
          else
            tf_cmds.push(cmd[1..-1])
            component_stack.push(:tf)
          end
        when 'end', 'stop'
          chunk = nil
          case component_stack.pop
          when :tf
            tf_cmds.pop
          when :var, :hide
            vore_stack.pop
          end
        when 'endall', 'stopall'
          chunk = nil
          tf_cmds = []
          vore_stack = []
          component_stack = []
        when 'emojify'
          chunk = nil
          next if cmd[1].nil?
          src_img = nil
          shortcode = cmd[2]
          case cmd[1]
          when 'avatar'
            src_img = account.avatar
          when 'parent'
            next unless cmd[3].present? && reply?
            shortcode = cmd[3]
            parent_status = Status.where(id: in_reply_to_id).first
            next if parent_status.nil?
            case cmd[2]
            when 'avatar'
              src_img = parent_status.account.avatar
            end
          end

          next if src_img.nil? || shortcode.nil? || !shortcode.match?(/\A\w+\Z/)

          chunk = ":#{shortcode}:"
          emoji = CustomEmoji.find_or_initialize_by(shortcode: shortcode, domain: nil)
          if emoji.id.nil?
            emoji.image = src_img
            emoji.save
          end
        when 'emoji'
          next if cmd[1].nil?
          shortcode = cmd[1]
          domain = (cmd[2].blank? ? nil : cmd[2].downcase)
          chunk = ":#{shortcode}:"
          ours = CustomEmoji.find_or_initialize_by(shortcode: shortcode, domain: nil)
          if ours.id.nil?
            if domain.nil?
              theirs = CustomEmoji.find_by(shortcode: shortcode)
            else
              theirs = CustomEmoji.find_by(shortcode: shortcode, domain: domain)
            end
            unless theirs.nil?
              ours.image = theirs.image
              ours.save
            end
          end
        when 'char'
          chunk = nil
          charmap = {
            'zws' => "\u200b",
            'zwnj' => "\u200c",
            'zwj' => "\u200d",
            '\n' => "\n",
            '\r' => "\r",
            '\t' => "\t",
            '\T' => '    '
          }
          cmd[1..-1].each do |c|
            next if c.nil?
            if c.in?(charmap)
              chunks << charmap[cmd[1]]
            elsif (/^\h{1,5}$/ =~ c) && c.to_i(16) > 0
              begin
                chunks << [c.to_i(16)].pack('U*')
              rescue
                chunks << '?'
              end
            end
          end
        when 'link'
          chunk = nil
          case cmd[1]
          when 'permalink', 'self'
            chunk = TagManager.instance.url_for(self)
          when 'cloudroot'
            chunk = "https://monsterpit.cloud/~/#{account.username}"
          when 'blogroot'
            chunk = "https://monsterpit.blog/~/#{account.username}"
          end
        when 'ping'
          mentions = []
          case cmd[1]
          when 'admins'
            mentions = User.admins.map { |u| "@#{u.account.username}" }
            mentions.sort!
          when 'mods'
            mentions = User.moderators.map { |u| "@#{u.account.username}" }
            mentions.sort!
          when 'staff'
            mentions = User.admins.map { |u| "@#{u.account.username}" }
            mentions += User.moderators.map { |u| "@#{u.account.username}" }
            mentions.uniq!
            mentions.sort!
          end
          chunk = mentions.join(' ')
        when 'tag'
          chunk = nil
          records = []
          valid_name = /^[[:word:]_\-]*[[:alpha:]_·\-][[:word:]_\-]*$/
          cmd[1..-1].select {|t| t.present? && valid_name.match?(t)}.uniq.each do |name|
            next if self.tags.where(name: name).exists?
            tag = Tag.where(name: name).first_or_create(name: name)
            self.tags << tag
            records << tag
            TrendingTags.record_use!(tag, account, created_at) if distributable?
          end
          if public_visibility? || unlisted_visibility?
            account.featured_tags.where(tag_id: records.map(&:id)).each do |featured_tag|
              featured_tag.increment(created_at)
            end
          end
        when 'thread'
          chunk = nil
          case cmd[1]
          when 'reall'
            if conversation_id.present?
              mention_ids = Status.where(conversation_id: conversation_id).flat_map { |s| s.mentions.pluck(:account_id) }
              mention_ids.uniq!
              mentions = Account.where(id: mention_ids).map { |a| "@#{a.username}" }
              chunk = mentions.join(' ')
            end
          end
        when 'parent'
          chunk = nil
          next unless reply?
          parent_status = Status.where(id: in_reply_to_id).first
          next if parent_status.nil?
          case cmd[1]
          when 'edit'
            next unless reply? && in_reply_to_account_id == account_id
          when 'permalink'
            chunk = TagManager.instance.url_for(parent_status)
          end
        when 'media'
          chunk = nil

          media_idx = cmd[1]
          media_cmd = cmd[2]
          media_args = cmd[3..-1]

          next unless media_cmd.present? && media_idx.present? && media_idx.scan(/\D/).empty?
          media_idx = media_idx.to_i
          next if media_attachments[media_idx-1].nil?

          case media_cmd
          when 'desc'
            if media_args.present?
              vars["media_#{media_idx}_desc"] = media_args.join(':')
            else
              vore_stack.push("media_#{media_idx}_desc")
              component_stack.push(:var)
            end
          end

          post_cmds.push(['media', media_idx, media_cmd])
        when 'bangtag'
          chunk = chunk.sub('bangtag:', '').gsub(':', ":\u200c")
        when 'join'
          chunk = nil
          next if cmd[1].nil?
          charmap = {
            'zws' => "\u200b",
            'zwnj' => "\u200c",
            'zwj' => "\u200d",
            '\n' => "\n",
            '\r' => "\r",
            '\t' => "\t",
            '\T' => '    '
          }
          sep = charmap[cmd[1]]
          chunk = cmd[2..-1].join(sep.nil? ? cmd[1] : sep)
        when 'hide'
          chunk = nil
          case cmd[1]
          when 'end', 'stop', 'endall', 'stopall'
            vore_stack.reject! {|v| v == '_'}
            compontent_stack.reject! {|c| c == :hide}
          else
            if cmd[1].nil? && !'_'.in?(vore_stack)
              vore_stack.push('_')
              component_stack.push(:hide)
            end
          end
        when 'comment'
          chunk = nil
          if cmd[1].nil?
            vore_stack.push('_comment')
            component_stack.push(:var)
          end
        end
      end

      if chunk.present? && tf_cmds.present?
        tf_cmds.each do |tf_cmd|
          next if chunk.nil?
          case tf_cmd[0]
          when 'replace', 'sub', 's'
            tf_cmd[1..-1].in_groups_of(2) do |args|
              chunk.sub!(*args) if args.all?
            end
          when 'replaceall', 'gsub', 'gs'
            tf_cmd[1..-1].in_groups_of(2) do |args|
              chunk.gsub!(*args) if args.all?
            end
          end
        end
      end

      unless chunk.blank? || vore_stack.empty?
        var = vore_stack.last
        next if var == '_'
        if vars[var].nil?
          vars[var] = chunk.lstrip
        else
          vars[var] += chunk.rstrip
        end
        chunk = nil
      end

      chunks << chunk unless chunk.nil?
    end

    vars.transform_values! {|v| v.rstrip}

    if post_cmds.present?
      post_cmds.each do |post_cmd|
        case post_cmd[0]
        when 'media'
          media_idx = post_cmd[1]
          media_cmd = post_cmd[2]
          media_args = post_cmd[3..-1]

          case media_cmd
          when 'desc'
            media_attachments[media_idx-1].description = vars["media_#{media_idx}_desc"]
            media_attachments[media_idx-1].save
          end
        end
      end
    end

    self.text = chunks.join('')
    save
  end

  def set_conversation
    self.thread = thread.reblog if thread&.reblog?

    self.reply = !(in_reply_to_id.nil? && thread.nil?) unless reply

    if reply? && !thread.nil?
      self.in_reply_to_account_id = carried_over_reply_to_account_id
      self.conversation_id        = thread.conversation_id if conversation_id.nil?
    elsif conversation_id.nil?
      self.conversation = Conversation.new
    end
  end

  def carried_over_reply_to_account_id
    if thread.account_id == account_id && thread.reply?
      thread.in_reply_to_account_id
    else
      thread.account_id
    end
  end

  def set_local
    self.local = account.local?
    self.network = account.network?
  end

  def update_statistics
    return unless public_visibility? || unlisted_visibility?
    ActivityTracker.increment('activity:statuses:local')
  end

  def increment_counter_caches
    return if direct_visibility?

    account&.increment_count!(:statuses_count)
    reblog&.increment_count!(:reblogs_count) if reblog? && (public_visibility? || unlisted_visibility?)
    thread&.increment_count!(:replies_count) if in_reply_to_id.present? && (public_visibility? || unlisted_visibility?)
  end

  def decrement_counter_caches
    return if direct_visibility? || marked_for_mass_destruction?

    account&.decrement_count!(:statuses_count)
    reblog&.decrement_count!(:reblogs_count) if reblog? && (public_visibility? || unlisted_visibility?)
    thread&.decrement_count!(:replies_count) if in_reply_to_id.present? && (public_visibility? || unlisted_visibility?)
  end

  def unlink_from_conversations
    return unless direct_visibility?

    mentioned_accounts = mentions.includes(:account).map(&:account)
    inbox_owners       = mentioned_accounts.select(&:local?) + (account.local? ? [account] : [])

    inbox_owners.each do |inbox_owner|
      AccountConversation.remove_status(inbox_owner, self)
    end
  end
end
