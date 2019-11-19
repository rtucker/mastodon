# frozen_string_literal: true

class ActivityPub::ActivitySerializer < ActivityPub::Serializer
  attributes :id, :type, :actor, :published, :updated, :to, :cc

  has_one :proper, key: :object, serializer: ActivityPub::NoteSerializer, if: :serialize_object?
  attribute :proper_uri, key: :object, unless: :serialize_object?

  def id
    ActivityPub::TagManager.instance.activity_uri_for(object)
  end

  def type
    announce? ? 'Announce' : 'Create'
  end

  def actor
    ActivityPub::TagManager.instance.uri_for(object.account)
  end

  def published
    object.created_at.iso8601
  end

  def updated
    object.updated_at.iso8601
  end

  def to
    ActivityPub::TagManager.instance.to(object)
  end

  def cc
    ActivityPub::TagManager.instance.cc(object)
  end

  def proper_uri
    ActivityPub::TagManager.instance.uri_for(object.proper)
  end

  def announce?
    object.reblog?
  end

  def serialize_object?
    return true unless announce?
    # Serialize private self-boosts of local toots
    object.account == object.proper.account && object.proper.private_visibility? && object.local?
  end
end
