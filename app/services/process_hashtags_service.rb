# frozen_string_literal: true

class ProcessHashtagsService < BaseService
  def call(status, tags = [], preloaded_tags = [])
    status.tags |= preloaded_tags unless preloaded_tags.blank?

    if status.local?
      tags = Extractor.extract_hashtags(status.text) | (tags.nil? ? [] : tags)
    end
    records = []

    tags.map { |str| str.mb_chars.downcase }.uniq(&:to_s).each do |name|
      name.gsub!(/[:.]+/, '.')
      next if name.blank? || name == '.'

      chat = name.starts_with?('chat.', '.chat.')
      if chat
        component_indices = [name.size - 1]
      else
        component_indices = 1.upto(name.size).select { |i| name[i] == '.' }
        component_indices << name.size - 1
      end

      component_indices.take(6).each_with_index do |i, nest|
        frag = (nest != 5) ? name[0..i] : name
        tag = Tag.where(name: frag).first_or_create(name: frag)

        tag.chatters.find_or_create_by(id: status.account_id) if chat

        next if status.tags.include?(tag)
        status.tags << tag
        next if tag.unlisted || component_indices.size > 1

        records << tag
        TrendingTags.record_use!(tag, status.account, status.created_at) if status.distributable?
      end
    end

    return unless status.distributable?

    status.account.featured_tags.where(tag_id: records.map(&:id)).each do |featured_tag|
      featured_tag.increment(status.created_at)
    end
  end
end
