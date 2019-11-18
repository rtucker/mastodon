# frozen_string_literal: true

class REST::FilterSerializer < ActiveModel::Serializer
  attributes :id, :phrase, :expires_at

  def id
    object.id.to_s
  end
end
