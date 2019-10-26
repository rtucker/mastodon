# frozen_string_literal: true

require 'singleton'
require_relative './sanitize_config'

class HTMLRenderer < Redcarpet::Render::HTML
  def block_code(code, language)
    "<pre><code>#{encode(code).gsub("\n", "<br/>")}</code></pre>"
  end

  def autolink(link, link_type)
    return link if link_type == :email
    Formatter.instance.link_url(link)
  end

  private

  def html_entities
    @html_entities ||= HTMLEntities.new
  end

  def encode(html)
    html_entities.encode(html)
  end
end

class Formatter
  include Singleton
  include RoutingHelper

  include ActionView::Helpers::TextHelper

  CACHE_TIME = 1.hour

	BBCODE_TAGS = {
    url: {
			html_open: '<a href="%url%" rel="noopener nofollow" target="_blank">', html_close: '</a>',
			description: '', example: '',
      require_between: true,
      allow_quick_param: true, allow_between_as_param: true,
      quick_param_format: %r{^(\S+://\S+|/\S+)$},
      quick_param_format_description: '',
			param_tokens: [{token: :url}]
    },
		list: {
			html_open: '<ul>', html_close: '</ul>',
			description: '', example: '',
      only_allow: [:li, '*'.to_sym],
      block_tag: true,
		},
		ul: {
			html_open: '<ul>', html_close: '</ul>',
			description: '', example: '',
      only_allow: [:li, '*'.to_sym],
      block_tag: true,
		},
		ol: {
			html_open: '<ol>', html_close: '</ol>',
			description: '', example: '',
      only_allow: [:li, '*'.to_sym],
      block_tag: true,
		},
		li: {
			html_open: '<li>', html_close: '</li>',
			description: '', example: '',
      block_tag: true,
      only_in: %i[list ul ol]
		},
    '*': {
			html_open: '<li>', html_close: '</li>',
			description: '', example: '',
      self_closable: true, block_tag: true,
      only_in: %i[list ul ol]
		},
		sub: {
			html_open: '<sub>', html_close: '</sub>',
			description: '', example: '',
		},
		sup: {
			html_open: '<sup>', html_close: '</sup>',
			description: '', example: '',
		},
		h1: {
			html_open: '<h1>', html_close: '</h1>',
			description: '', example: '',
		},
		h2: {
			html_open: '<h2>', html_close: '</h2>',
			description: '', example: '',
		},
		h3: {
			html_open: '<h3>', html_close: '</h3>',
			description: '', example: '',
		},
		h4: {
			html_open: '<h4>', html_close: '</h4>',
			description: '', example: '',
		},
		h5: {
			html_open: '<h5>', html_close: '</h5>',
			description: '', example: '',
		},
		h6: {
			html_open: '<h6>', html_close: '</h6>',
			description: '', example: '',
		},
		abbr: {
			html_open: '<abbr>', html_close: '</abbr>',
			description: '', example: '',
		},
		hr: {
			html_open: '<hr>', html_close: '</hr>',
			description: '', example: '',
		},
		b: {
			html_open: '<strong>', html_close: '</strong>',
			description: '', example: '',
		},
		i: {
			html_open: '<em>', html_close: '</em>',
			description: '', example: '',
		},
		flip: {
			html_open: '<span class="bbcode__flip-%direction%">', html_close: '</span>',
			description: '', example: '',
			allow_quick_param: true, allow_between_as_param: false,
			quick_param_format: /(h|v)/,
			param_tokens: [{token: :direction}]
    },
		size: {
			html_open: '<span class="bbcode__size-%size%">', html_close: '</span>',
			description: '', example: '',
			allow_quick_param: true, allow_between_as_param: false,
			quick_param_format: /([1-6])/,
			param_tokens: [{token: :size}]
    },
		quote: {
			html_open: '<blockquote>', html_close: '</blockquote>',
			description: '', example: '',
      block_tag: true,
    },
		kbd: {
			html_open: '<pre><code>', html_close: '</code></pre>',
			description: '', example: '',
    },
		code: {
			html_open: '<pre><code>', html_close: '</code></pre>',
			description: '', example: '',
      block_tag: true,
    },
		u: {
			html_open: '<u>', html_close: '</u>',
			description: '', example: '',
    },
		s: {
			html_open: '<s>', html_close: '</s>',
			description: '', example: '',
    },
		del: {
			html_open: '<del>', html_close: '</del>',
			description: '', example: '',
    },
		left: {
			html_open: '<span class="bbcode__left">', html_close: '</span>',
			description: '', example: '',
    },
		center: {
			html_open: '<span class="bbcode__center">', html_close: '</span>',
			description: '', example: '',
    },
		right: {
			html_open: '<span class="bbcode__right">', html_close: '</span>',
			description: '', example: '',
    },
		lfloat: {
			html_open: '<span class="bbcode__lfloat">', html_close: '</span>',
			description: '', example: '',
    },
		rfloat: {
			html_open: '<span class="bbcode__rfloat">', html_close: '</span>',
			description: '', example: '',
    },
		spoiler: {
			html_open: '<span class="bbcode__spoiler-wrapper"><span class="bbcode__spoiler">', html_close: '</span></span>',
			description: '', example: '',
    },
	}

  def format(status, **options)
    unless options[:skip_cache]
      html = Rails.cache.fetch()
      unless html.nil?
        html = encode_custom_emojis(html, status.emojis, options[:autoplay]) if options[:custom_emojify]
        return html.html_safe # rubocop:disable Rails/OutputSafety
      end
    end

    orig_status = status

    if status.reblog?
      prepend_reblog = status.reblog.account.acct
      status         = status.proper
    else
      prepend_reblog = false
    end

    raw_content = status.text

    if options[:inline_poll_options] && status.preloadable_poll
      raw_content = raw_content + "\n\n" + status.preloadable_poll.options.map { |title| "[ ] #{title}" }.join("\n")
    end

    return '' if raw_content.blank?

    unless status.local?
      html = reformat(raw_content)

      Rails.cache.write("formatted_status:#{orig_status.id}", html, expires_in: CACHE_TIME)

      html = encode_custom_emojis(html, status.emojis, options[:autoplay]) if options[:custom_emojify]
      return html.html_safe # rubocop:disable Rails/OutputSafety
    end

    linkable_accounts = status.active_mentions.map(&:account)
    linkable_accounts << status.account

    html = raw_content
    html = "RT @#{prepend_reblog} #{html}" if prepend_reblog

    case status.content_type
    when 'text/markdown'
      html = format_markdown(html)
    when 'text/x-bbcode'
      html = format_bbcode(html)
    when 'text/x-bbcode+markdown'
      html = format_bbdown(html)
    end

    html = format_screenreader(html)

    html = encode_and_link_urls(html, linkable_accounts, keep_html: %w(text/markdown text/x-bbcode text/x-bbcode+markdown text/html).include?(status.content_type))

    if %w(text/markdown text/x-bbcode text/x-bbcode+markdown text/html).include?(status.content_type)
      is_html = status.content_type == 'text/html'
      html = reformat(html, strip_newlines: !is_html)
      html.gsub!("\n", '<br>') if is_html
    else
      html = simple_format(html, {}, sanitize: false)
      html = html.delete("\n")
      html = format_console(html) if status.content_type == 'text/console'
    end

    unless status.footer.blank?
      footer = status.footer
      footer = encode_and_link_urls(footer)
      html = "#{html.strip}\n<p class=\"signature\">— #{footer}</p>"
    end

    Rails.cache.write("formatted_status:#{orig_status.id}", html, expires_in: CACHE_TIME)

    html = encode_custom_emojis(html, status.emojis, options[:autoplay]) if options[:custom_emojify]
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_screenreader(html)
    html.gsub(/\ufdd3(.*)\ufdd4/m, '<span aria-hidden="true">\1</span>')
  end

  def format_console(html)
    cursor = '<span class="cursor"></span>'
    "<pre><code>#{html.strip.sub(/<\/p>\Z/, cursor)}</p></code></pre>"
  end

  def format_markdown(html)
    html = markdown_formatter.render(html)
  end

  def format_bbcode(html)
    html = bbcode_formatter(html)
    html.gsub(/<hr>.*<\/hr>/im, '<hr />')
  end

  def format_bbdown(html)
    html = format_bbcode(html)
    html = html.gsub(/<br *\/>|<br>/, '')
    format_markdown(html)
  end

  def reformat(html, strip_newlines: true)
    html = sanitize(html, Sanitize::Config::MASTODON_STRICT)
    return html.delete("\r").delete("\n") if strip_newlines
    html.gsub!("\r\n", "\n")
    html.gsub!("\n\r", "\n")
    html.gsub("\r", "\n")
  end

  def plaintext(status)
    return status.text if status.local?

    text = status.text.gsub(/(<br \/>|<br>|<\/p>)+/) { |match| "#{match}\n" }
    strip_tags(text)
  end

  def simplified_format(account, **options)
    unless options[:skip_cache]
      html = Rails.cache.fetch("formatted_account:#{account.id}")
      unless html.nil?
        html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if account.local && options[:custom_emojify]
        return html.html_safe # rubocop:disable Rails/OutputSafety
      end
    end

    if account.local?
      html = format_bbdown(account.note)
      html = encode_and_link_urls(html, keep_html: true)
      html = reformat(html)
    else
      html = reformat(account.note)
    end

    Rails.cache.write("formatted_account:#{account.id}", html, expires_in: CACHE_TIME)

    html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if account.local && options[:custom_emojify]
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def sanitize(html, config)
    Sanitize.fragment(html, config)
  end

  def format_spoiler(status, **options)
    unless options[:skip_cache]
      html = Rails.cache.fetch("formatted_spoiler:#{status.id}")
      unless html.nil?
        html = encode_custom_emojis(html, status.emojis, options[:autoplay])
        return html.html_safe # rubocop:disable Rails/OutputSafety
      end
    end

    html = encode(status.spoiler_text)

    Rails.cache.write("formatted_spoiler:#{status.id}", html, expires_in: CACHE_TIME)

    html = encode_custom_emojis(html, status.emojis, options[:autoplay])
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_poll_option(status, option, **options)
    unless options[:skip_cache]
      html = Rails.cache.fetch("formatted_poll:#{status.id}:#{option.id}")
      unless html.nil?
        html = encode_custom_emojis(html, status.emojis, options[:autoplay])
        return html.html_safe # rubocop:disable Rails/OutputSafety
      end
    end

    html = encode(option.title)

    Rails.cache.write("formatted_poll:#{status.id}:#{option.id}", html, expires_in: CACHE_TIME)

    html = encode_custom_emojis(html, status.emojis, options[:autoplay])
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_display_name(account, **options)
    unless options[:skip_cache]
      html = Rails.cache.fetch("formatted_display_name:#{account.id}")
      unless html.nil?
        html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if options[:custom_emojify]
        return html.html_safe # rubocop:disable Rails/OutputSafety
      end
    end

    html = encode(account.display_name.presence || account.username)

    Rails.cache.write("formatted_display_name:#{account.id}", html, expires_in: CACHE_TIME)

    html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if options[:custom_emojify]
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_field(account, str, **options)
    return reformat(str).html_safe unless account.local? # rubocop:disable Rails/OutputSafety
    html = encode_and_link_urls(str, me: true)
    html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if options[:custom_emojify]
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def linkify(text)
    html = encode_and_link_urls(text)
    html = simple_format(html, {}, sanitize: false)
    html = html.delete("\n")

    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def link_url(url)
    "<a href=\"#{encode(url)}\" target=\"blank\" rel=\"nofollow noopener\">#{link_html(url)}</a>"
  end

  private

  def bbcode_formatter(html)
    begin
      html.gsub!(/\[(?=[^\w\/])/, "\ufdd6")
      html = html.bbcode_to_html(false, BBCODE_TAGS, :enable, *BBCODE_TAGS.keys)
      html.gsub!("\ufdd6", '[')
    rescue Exception => e
    end
    html
  end

  def markdown_formatter
    return @markdown_formatter if defined?(@markdown_formatter)

    extensions = {
      autolink: true,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      disable_indented_code_blocks: true,
      strikethrough: true,
      lax_spacing: true,
      space_after_headers: true,
      superscript: true,
      underline: true,
      highlight: true,
      footnotes: false,
    }

    renderer = HTMLRenderer.new({
      filter_html: false,
      escape_html: false,
      no_images: true,
      no_styles: true,
      safe_links_only: true,
      hard_wrap: true,
      link_attributes: { target: '_blank', rel: 'nofollow noopener' },
    })

    @markdown_formatter = Redcarpet::Markdown.new(renderer, extensions)
  end

  def html_entities
    @html_entities ||= HTMLEntities.new
  end

  def encode(html)
    html_entities.encode(html)
  end

  def encode_and_link_urls(html, accounts = nil, options = {})
    if accounts.is_a?(Hash)
      options  = accounts
      accounts = nil
    end

    entities = options[:keep_html] ? html_friendly_extractor(html) : utf8_friendly_extractor(html, extract_url_without_protocol: false)

    rewrite(html.dup, entities, options[:keep_html]) do |entity|
      if entity[:url]
        link_to_url(entity, options)
      elsif entity[:hashtag]
        link_to_hashtag(entity)
      elsif entity[:screen_name]
        link = link_to_pseudo(entity[:screen_name])
        link.nil? ? link_to_mention(entity, accounts) : link
      end
    end
  end

  def count_tag_nesting(tag)
    if tag[1] == '/' then -1
    elsif tag[-2] == '/' then 0
    else 1
    end
  end

  def encode_custom_emojis(html, emojis, animate = false)
    return html if emojis.empty?

    emoji_map = if animate
                  emojis.each_with_object({}) { |e, h| h[e.shortcode] = full_asset_url(e.image.url) }
                else
                  emojis.each_with_object({}) { |e, h| h[e.shortcode] = full_asset_url(e.image.url(:static)) }
                end

    i                     = -1
    tag_open_index        = nil
    inside_shortname      = false
    shortname_start_index = -1
    invisible_depth       = 0

    while i + 1 < html.size
      i += 1

      if invisible_depth.zero? && inside_shortname && html[i] == ':'
        shortcode = html[shortname_start_index + 1..i - 1]
        emoji     = emoji_map[shortcode]

        if emoji
          replacement = "<img draggable=\"false\" class=\"emojione\" alt=\":#{encode(shortcode)}:\" title=\":#{encode(shortcode)}:\" src=\"#{encode(emoji)}\" />"
          before_html = shortname_start_index.positive? ? html[0..shortname_start_index - 1] : ''
          html        = before_html + replacement + html[i + 1..-1]
          i          += replacement.size - (shortcode.size + 2) - 1
        else
          i -= 1
        end

        inside_shortname = false
      elsif tag_open_index && html[i] == '>'
        tag = html[tag_open_index..i]
        tag_open_index = nil
        if invisible_depth.positive?
          invisible_depth += count_tag_nesting(tag)
        elsif tag == '<span class="invisible">'
          invisible_depth = 1
        end
      elsif html[i] == '<'
        tag_open_index   = i
        inside_shortname = false
      elsif !tag_open_index && html[i] == ':'
        inside_shortname      = true
        shortname_start_index = i
      end
    end

    html
  end

  def rewrite(text, entities, keep_html = false)
    text = text.to_s

    # Sort by start index
    entities = entities.sort_by do |entity|
      indices = entity.respond_to?(:indices) ? entity.indices : entity[:indices]
      indices.first
    end

    result = []

    last_index = entities.reduce(0) do |index, entity|
      indices = entity.respond_to?(:indices) ? entity.indices : entity[:indices]
      result << (keep_html ? text[index...indices.first] : encode(text[index...indices.first]))
      result << yield(entity)
      indices.last
    end

    result << (keep_html ? text[last_index..-1] : encode(text[last_index..-1]))

    result.flatten.join
  end

  UNICODE_ESCAPE_BLACKLIST_RE = /\p{Z}|\p{P}/

  def utf8_friendly_extractor(text, options = {})
    old_to_new_index = [0]

    escaped = text.chars.map do |c|
      output = begin
        if c.ord.to_s(16).length > 2 && UNICODE_ESCAPE_BLACKLIST_RE.match(c).nil?
          CGI.escape(c)
        else
          c
        end
      end

      old_to_new_index << old_to_new_index.last + output.length

      output
    end.join

    # Note: I couldn't obtain list_slug with @user/list-name format
    # for mention so this requires additional check
    special = Extractor.extract_urls_with_indices(escaped, options).map do |extract|
      new_indices = [
        old_to_new_index.find_index(extract[:indices].first),
        old_to_new_index.find_index(extract[:indices].last),
      ]

      next extract.merge(
        indices: new_indices,
        url: text[new_indices.first..new_indices.last - 1]
      )
    end

    standard = Extractor.extract_entities_with_indices(text, options)

    Extractor.remove_overlapping_entities(special + standard)
  end

  def html_friendly_extractor(html, options = {})
    gaps = []
    total_offset = 0

    escaped = html.gsub(/<[^>]*>/) do |match|
      total_offset += match.length - 1
      end_offset = Regexp.last_match.end(0)
      gaps << [end_offset - total_offset, total_offset]
      "\u200b"
    end

    entities = Extractor.extract_hashtags_with_indices(escaped, :check_url_overlap => false) +
               Extractor.extract_mentions_or_lists_with_indices(escaped)
    Extractor.remove_overlapping_entities(entities).map do |extract|
      pos = extract[:indices].first
      offset_idx = gaps.rindex { |gap| gap.first <= pos }
      offset = offset_idx.nil? ? 0 : gaps[offset_idx].last
      next extract.merge(
        :indices => [extract[:indices].first + offset, extract[:indices].last + offset]
      )
    end
  end

  def link_to_url(entity, options = {})
    url        = Addressable::URI.parse(entity[:url])
    html_attrs = { target: '_blank', rel: 'nofollow noopener' }

    html_attrs[:rel] = "me #{html_attrs[:rel]}" if options[:me]

    Twitter::Autolink.send(:link_to_text, entity, link_html(entity[:url]), url, html_attrs)
  rescue Addressable::URI::InvalidURIError, IDN::Idna::IdnaError
    encode(entity[:url])
  end

  def link_to_mention(entity, linkable_accounts)
    acct = entity[:screen_name]

    return link_to_account(acct) unless linkable_accounts

    account = linkable_accounts.find { |item| TagManager.instance.same_acct?(item.acct, acct) }

    username, domain = acct.split('@', 2)
    domain = (Rails.configuration.x.web_domain || Rails.configuration.x.local_domain) if domain.nil?

    account ? mention_html(account) : anchor_html("@#{acct}", "https://#{domain}/@#{username}")
  end

  def link_to_account(acct)
    username, domain = acct.split('@', 2)

    domain  = nil if TagManager.instance.local_domain?(domain)
    account = EntityCache.instance.mention(username, domain)
    domain = (Rails.configuration.x.web_domain || Rails.configuration.x.local_domain) if domain.nil?

    account ? mention_html(account) : anchor_html("@#{acct}", "https://#{domain}/@#{username}")
  end

  def link_to_hashtag(entity)
    hashtag_html(entity[:hashtag])
  end

  def link_html(url)
    url    = Addressable::URI.parse(url).to_s
    prefix = url.match(/\Ahttps?:\/\/(www\.)?/).to_s
    text   = url[prefix.length, 30]
    suffix = url[prefix.length + 30..-1]
    cutoff = url[prefix.length..-1].length > 30

    "<span class=\"invisible\">#{encode(prefix)}</span><span class=\"#{cutoff ? 'ellipsis' : ''}\">#{encode(text)}</span><span class=\"invisible\">#{encode(suffix)}</span>"
  end

  def hashtag_html(tag)
    "<a href=\"#{encode(tag_url(tag.downcase))}\" class=\"mention hashtag\" rel=\"tag\">#<span>#{encode(tag)}</span></a>"
  end

  def mention_html(account)
    "<span class=\"h-card\"><a href=\"#{encode(TagManager.instance.url_for(account))}\" class=\"u-url mention\">@<span>#{encode(account.username)}</span></a></span>"
  end

  def anchor_html(text, url)
    "<a href=\"#{encode(url)}\" rel=\"noopener noreferrer\"><span>#{encode(text)}</span></a>"
  end

  def link_to_pseudo(acct)
    username, domain = acct.split('@', 2)
    case domain
    when 'twitter', 'twitter.com'
      anchor_html("@#{username}@twitter.com", "https://twitter.com/#{username}")
    when 'tumblr', 'tumblr.com'
      anchor_html("#{username}@tumblr.com", "https://#{username}.tumblr.com")
    when 'weasyl', 'weasyl.com'
      anchor_html("#{username}@weasyl.com", "https://weasyl.com/~#{username}")
    when 'furaffinity', 'fa', 'furaffinity.net'
      anchor_html("#{username}@furaffinity.net", "https://furaffinity.net/user/#{username}")
    when 'furrynetwork', 'fn', 'furrynetwork.com', 'beta.furrynetwork.com'
      anchor_html("#{username}@furrynetwork.com", "https://furrynetwork.com/#{username}")
    when 'sofurry', 'sf', 'sofurry.com'
      anchor_html("#{username}@sofurry.com", "https://#{username}.sofurry.com")
    when 'inkbunny', 'ib', 'inkbunny.net'
      anchor_html("#{username}@inkbunny.net", "https://inkbunny.net/#{username}")
    when 'e621', 'e6', 'e621.net'
      anchor_html("#{username}@e621.net", "https://e621.net/user/show/#{username}")
    when 'e926', 'e9', 'e926.net'
      anchor_html("#{username}@e926.net", "https://e926.net/user/show/#{username}")
    when 'f-list', 'flist', 'fl', 'f-list.net'
      anchor_html("#{username}@f-list.net", "https://f-list.net/c/#{username}")
    when 'deviantart', 'da', 'deviantart.com'
      anchor_html("#{username}@deviantart.com", "https://#{username}.deviantart.com")
    when 'artstation', 'as', 'artstation.com'
      anchor_html("#{username}@artstation.com", "https://www.artstation.com/#{username}")
    when 'github', 'gh', 'github.com'
      anchor_html("#{username}@github.com", "https://github.com/#{username}")
    when 'gitlab', 'gl', 'gitlab.com'
      anchor_html("#{username}@gitlab.com", "https://gitlab.com/#{username}")
    else
      nil
    end
  end
end
