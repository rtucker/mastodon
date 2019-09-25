# frozen_string_literal: true

class REST::FilterSerializer < ActiveModel::Serializer
  attributes :id, :phrase, :context, :whole_word, :expires_at,
             :irreversible, :exclude_media, :media_only

  def id
    object.id.to_s
  end

  def irreversible
    true
  end
end
