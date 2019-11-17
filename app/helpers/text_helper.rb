# coding: utf-8
require 'htmlentities'
require 'sixarm_ruby_unaccent'

module TextHelper

  def normalize_text(html)
    t = html.downcase

    t.gsub!(/<(?:p|pre|blockquote|code|h[1-6]|li)\b[^>]*>/, "\n")
    t.gsub!(/<[bh]r[\/ ]*>/, "\n")
    t.gsub!(/<\/?[^>]*>/, '')

    t = HTMLEntities.new.decode(t)

    t.gsub!(/[ \t]*\302\240+[ \t]*/, ' ')
    t.gsub!(/  +/, ' ')

    t.gsub!(/\r\n?/, "\n")
    t.gsub!(/\n[ \t]+/, "\n")
    t.gsub!(/[ \t]+\n/, "\n")
    t.gsub!(/\n\n+/, "\n")

    return t.strip.unaccent_via_split_map unless '#'.in?(t)

    tags = Extractor.extract_hashtags(t).uniq
    t.gsub!(/^(?:#[\w:._·\-]+\s*)+/, '')
    t.gsub!(/(?:#[\w:._·\-]+\s*)+$/, '')

    t.delete!('#')

    "#{tags.join(' ')}\n#{t.lstrip}".strip.unaccent_via_split_map
  end

  def normalize_status(status, cache: true, skip_cache: true)
    normalize_text("#{status.tags.pluck(:name).join(' ')}\n#{status.spoiler_text}\n#{status.local? ? Formatter.instance.format(status, skip_cache: skip_cache, cache: cache) : status.text}")
  end
end
