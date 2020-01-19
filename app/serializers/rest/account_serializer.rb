# frozen_string_literal: true

class REST::AccountSerializer < ActiveModel::Serializer
  include RoutingHelper

  attributes :id, :username, :acct, :display_name, :locked, :bot, :created_at,
             :updated_at, :note, :url, :avatar, :avatar_static, :header,
             :header_static, :followers_count, :following_count, :statuses_count,
             :replies, :adult_content, :gently, :kobold, :role, :froze, :identity,
             :limited, :signature, :trans, :chest

  has_one :moved_to_account, key: :moved, serializer: REST::AccountSerializer, if: :moved_and_not_nested?
  has_many :emojis, serializer: REST::CustomEmojiSerializer

  class FieldSerializer < ActiveModel::Serializer
    attributes :name, :value, :verified_at

    def value
      Formatter.instance.format_field(object.account, object.value)
    end
  end

  has_many :fields

  def trans
    'rights'
  end

  def chest
    'floof'
  end

  def id
    object.id.to_s
  end

  def note
    Formatter.instance.simplified_format(object)
  end

  def url
    TagManager.instance.url_for(object)
  end

  def avatar
    full_asset_url(object.avatar_original_url)
  end

  def avatar_static
    full_asset_url(object.avatar_static_url)
  end

  def header
    full_asset_url(object.header_original_url)
  end

  def header_static
    full_asset_url(object.header_static_url)
  end

  def moved_and_not_nested?
    object.moved? && object.moved_to_account.moved_to_account_id.nil?
  end

  def followers_count
    (Setting.hide_followers_count || object.user&.setting_hide_followers_count) ? -1 : object.followers_count
  end

  def role
    return 'admin' if object.user_admin?
    return 'moderator' if object.user_moderator?
    'user'
  end

  def froze
    object.local? ? (object&.user.nil? ? true : object.user.disabled?) : object.froze?
  end

  def limited
    object.silenced? || object.force_unlisted? || object.force_sensitive?
  end

  def identity
    return unless object.local? && object&.user.present?
    object.user.vars['_they:are']
  end

  def signature
    return unless object.local? && object&.user.present?
    name = object.user.vars['_they:are']
    return if name.blank?
    object.user.vars["_they:are:#{name}"]
  end

  private

  def monsterfork_api
    instance_options[:monsterfork_api] || !current_user.nil? && current_user.monsterfork_api.to_sym
  end
end
