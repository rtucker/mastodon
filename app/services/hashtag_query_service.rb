# frozen_string_literal: true

class HashtagQueryService < BaseService
  def call(tag, params, account = nil, local = false, priv = false)
    tags = tags_for(Array(tag.name) | Array(params[:any]))
    all  = tags_for(params[:all])
    none = tags_for(params[:none])

    all_tags = Array(tags) | Array(all) | Array(none)
    local = all_tags.any? { |t| t.local } unless local
    priv = all_tags.any? { |t| t.private } unless priv

    tags = tags.pluck(:id)

    Status.distinct
          .as_tag_timeline(tags, account, local, priv)
          .tagged_with_all(all)
          .tagged_with_none(none)
  end

  private

  def tags_for(tags)
    Tag.where(name: tags.map(&:downcase)) if tags.presence
  end
end
