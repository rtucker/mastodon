# frozen_string_literal: true

class REST::StatusSerializer < ActiveModel::Serializer
  include Redisable

  attributes :id, :created_at, :updated_at, :in_reply_to_id,
             :in_reply_to_account_id, :sensitive, :spoiler_text, :visibility,
             :language, :uri, :url, :replies_count, :reblogs_count,
             :favourites_count, :network, :curated, :reject_replies, :trans,
             :chest

  attribute :favourited, if: :current_user?
  attribute :reblogged, if: :current_user?
  attribute :muted, if: :current_user?
  attribute :bookmarked, if: :current_user?
  attribute :pinned, if: :pinnable?
  attribute :local_only if :local?
  attribute :sharekey, if: :has_sharekey?
  attribute :delete_after, if: :current_user?
  attribute :defederate_after, if: :current_user?

  attribute :content, unless: :source_requested?
  attribute :text, if: :source_requested?
  attribute :content_type, if: :source_requested?

  belongs_to :reblog, serializer: REST::StatusSerializer
  belongs_to :application, if: :show_application?
  belongs_to :account, serializer: REST::AccountSerializer

  has_many :media_attachments, serializer: REST::MediaAttachmentSerializer
  has_many :ordered_mentions, key: :mentions
  has_many :tags
  has_many :emojis, serializer: REST::CustomEmojiSerializer

  has_one :preview_card, key: :card, serializer: REST::PreviewCardSerializer, if: :card_not_filtered?
  has_one :preloadable_poll, key: :poll, serializer: REST::PollSerializer

  def trans
    'rights'
  end

  def chest
    'floof'
  end

  def id
    object.id.to_s
  end

  def in_reply_to_id
    object.in_reply_to_id&.to_s
  end

  def in_reply_to_account_id
    object.in_reply_to_account_id&.to_s
  end

  def current_user?
    !current_user.nil?
  end

  def owner?
    current_user? && current_user.account_id == object.account_id
  end

  def has_sharekey?
    owner? && object.sharekey.present?
  end

  def show_application?
    object.account.user_shows_application? || owner?
  end

  def sharekey
    object.sharekey.key
  end

  def visibility
    if object.limited_visibility?
      'private'
    elsif monsterfork_api != :full && object.local_visibility?
      'unlisted'
    else
      object.visibility
    end
  end

  def uri
    ActivityPub::TagManager.instance.uri_for(object)
  end

  def content
    Formatter.instance.format(object)
  end

  def text
    "#{object.proper.text}\n\n#{object.tags.pluck(:name).sort.map{ |t| "##{t}" }.join(' ')}"
  end

  def url
    ActivityPub::TagManager.instance.url_for(object)
  end

  def favourited
    if instance_options && instance_options[:relationships]
      instance_options[:relationships].favourites_map[object.id] || false
    else
      current_user.account.favourited?(object)
    end
  end

  def reblogged
    if instance_options && instance_options[:relationships]
      instance_options[:relationships].reblogs_map[object.id] || false
    else
      current_user.account.reblogged?(object)
    end
  end

  def muted
    if instance_options && instance_options[:relationships]
      instance_options[:relationships].mutes_map[object.conversation_id] || false
    else
      current_user.account.muting_conversation?(object.conversation)
    end
  end

  def bookmarked
    if instance_options && instance_options[:bookmarks]
      instance_options[:bookmarks].bookmarks_map[object.id] || false
    else
      current_user.account.bookmarked?(object)
    end
  end

  def pinned
    if instance_options && instance_options[:relationships]
      instance_options[:relationships].pins_map[object.id] || false
    else
      current_user.account.pinned?(object)
    end
  end

  def pinnable?
    current_user? &&
      current_user.account_id == object.account_id &&
      !object.reblog? &&
      %w(public unlisted local private).include?(object.visibility)
  end

  def source_requested?
    instance_options[:source_requested]
  end

  def card_not_filtered?
    !(current_user? && current_user.hides_sensitive_cards? && object.sensitive?)
  end

  def ordered_mentions
    object.active_mentions.to_a.sort_by(&:id)
  end

  def delete_after
    object.delete_after
  end

  def defederate_after
    object.defederate_after
  end

  def reject_replies
    object.reject_replies == true
  end

  class ApplicationSerializer < ActiveModel::Serializer
    attributes :name, :website
  end

  class MentionSerializer < ActiveModel::Serializer
    attributes :id, :username, :url, :acct

    def id
      object.account_id.to_s
    end

    def username
      object.account_username
    end

    def url
      ActivityPub::TagManager.instance.url_for(object.account)
    end

    def acct
      object.account_acct
    end
  end

  class TagSerializer < ActiveModel::Serializer
    include RoutingHelper

    attributes :name, :url

    def url
      tag_url(object)
    end
  end

  private

  def monsterfork_api
    instance_options[:monsterfork_api] || current_user? && current_user.monsterfork_api.to_sym
  end
end
