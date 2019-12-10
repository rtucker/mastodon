# coding: utf-8
require 'htmlentities'
require 'sixarm_ruby_unaccent'

module TextHelper

  def html2text(html)
    html = html
      .gsub(/<(?:p|pre|blockquote|code|h[1-6]|li)\b[^>]*>/, "\n")
      .gsub(/<[bh]r[\/ ]*>/, "\n")
      .gsub(/<\/?[^>]*>/, '')

    HTMLEntities.new.decode(html)
  end

  def normalize_text(html)
    html.downcase
      .gsub(/[ \t]*\302\240+[ \t]*/, ' ')
      .gsub(/  +/, ' ')
      .gsub(/\r\n?/, "\n")
      .gsub(/\n[ \t]+/, "\n")
      .gsub(/[ \t]+\n/, "\n")
      .gsub(/\n\n+/, "\n")
      .gsub(/^(?:#[\w:._·\-]+\s*)+/, '')
      .gsub(/(?:#[\w:._·\-]+\s*)+$/, '')
      .delete('#')
      .strip
      .unaccent_via_split_map
  end

  def normalize_status(status)
    "#{_format_tags(status)}\n#{_format_spoiler(status)}\n#{_format_status(status)}\n#{_format_desc(status)}".strip
  end

  def _format_tags(status)
    return unless status.tags.present?
    "tag #{status.tags.pluck(:name).join("\ntag ")}"
  end

  def _format_spoiler(status)
    return if status.spoiler_text.blank?
    "subj #{normalize_text(status.spoiler_text)}"
  end

  def _format_status(status)
    text = status.local? ? Formatter.instance.format(status) : status.text
    return if text.blank?
    text = normalize_text(html2text(text))
    text.gsub!("\n", "\ntext ")
    "text #{text}"
  end

  def _format_desc(status)
    return unless status.media_attachments.present?
    text = status.media_attachments.pluck(:description).join("\ndesc ")
    "desc #{normalize_text(text)}"
  end
end
