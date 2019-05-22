# frozen_string_literal: true

class ProcessHashtagsService < BaseService
  def call(status, tags = [])
    if status.local?
      tags = Extractor.extract_hashtags(status.text) | (tags.nil? ? [] : tags)
    end
    records = []

    tags.map { |str| str.mb_chars.downcase }.uniq(&:to_s).each do |name|
      name = name.gsub(/[:.]+/, '.')
      next if name.blank?
      component_indices = name.size.times.select {|i| name[i] == '.'}
      component_indices << name.size - 1
      component_indices.take(6).each_with_index do |i, nest|
        frag = (nest != 5) ? name[0..i] : name
        tag = Tag.where(name: frag).first_or_create(name: frag)

        next if status.tags.include?(tag)
        status.tags << tag
        next if tag.local || tag.private

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
