# frozen_string_literal: true

class ActivityPub::Adapter < ActiveModelSerializers::Adapter::Base
  NAMED_CONTEXT_MAP = {
    activitystreams: 'https://www.w3.org/ns/activitystreams',
    security: 'https://w3id.org/security/v1',
  }.freeze

  CONTEXT_EXTENSION_MAP = {
    manually_approves_followers: { 'manuallyApprovesFollowers' => 'as:manuallyApprovesFollowers' },
    sensitive: { 'sensitive' => 'as:sensitive' },
    hashtag: { 'Hashtag' => 'as:Hashtag' },
    moved_to: { 'movedTo' => { '@id' => 'as:movedTo', '@type' => '@id' } },
    also_known_as: { 'alsoKnownAs' => { '@id' => 'as:alsoKnownAs', '@type' => '@id' } },
    emoji: { 'toot' => 'http://joinmastodon.org/ns#', 'Emoji' => 'toot:Emoji' },
    featured: { 'toot' => 'http://joinmastodon.org/ns#', 'featured' => { '@id' => 'toot:featured', '@type' => '@id' } },
    property_value: { 'schema' => 'http://schema.org#', 'PropertyValue' => 'schema:PropertyValue', 'value' => 'schema:value' },
    conversation: { 'ostatus' => 'http://ostatus.org#', 'conversation' => 'ostatus:conversation' },
    focal_point: { 'toot' => 'http://joinmastodon.org/ns#', 'focalPoint' => { '@container' => '@list', '@id' => 'toot:focalPoint' } },
    identity_proof: { 'toot' => 'http://joinmastodon.org/ns#', 'IdentityProof' => 'toot:IdentityProof' },
    blurhash: { 'toot' => 'http://joinmastodon.org/ns#', 'blurhash' => 'toot:blurhash' },

    adult_content: {
      'mp' => 'https://monsterpit.net/ns#',
      'adultContent' => 'mp:adultContent'
    },
    gently: {
      'mp' => 'https://monsterpit.net/ns#',
      'gently' => 'mp:gently'
    },
    kobold: {
      'mp' => 'https://monsterpit.net/ns#',
      'kobold' => 'mp:kobold'
    },
    supports_chat: {
      'mp' => 'https://monsterpit.net/ns#',
      'supportsChat' => 'mp:supportsChat'
    },
    locked: {
      'mp' => 'https://monsterpit.net/ns#',
      'locked' => 'mp:locked'
    },
  }.freeze

  def self.default_key_transform
    :camel_lower
  end

  def self.transform_key_casing!(value, _options)
    ActivityPub::CaseTransform.camel_lower(value)
  end

  def serializable_hash(options = nil)
    options         = serialization_options(options)
    serialized_hash = serializer.serializable_hash(options)
    serialized_hash = self.class.transform_key_casing!(serialized_hash, instance_options)

    { '@context' => serialized_context }.merge(serialized_hash)
  end

  private

  def serialized_context
    context_array = []

    serializer_options = serializer.send(:instance_options) || {}
    named_contexts     = [:activitystreams] + serializer._named_contexts.keys + serializer_options.fetch(:named_contexts, {}).keys
    context_extensions = serializer._context_extensions.keys + serializer_options.fetch(:context_extensions, {}).keys

    named_contexts.each do |key|
      context_array << NAMED_CONTEXT_MAP[key]
    end

    extensions = context_extensions.each_with_object({}) do |key, h|
      h.merge!(CONTEXT_EXTENSION_MAP[key])
    end

    context_array << extensions unless extensions.empty?

    if context_array.size == 1
      context_array.first
    else
      context_array
    end
  end
end
