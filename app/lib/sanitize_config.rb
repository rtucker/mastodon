# frozen_string_literal: true

class Sanitize
  module Config
    HTTP_PROTOCOLS ||= ['http', 'https', 'dat', 'dweb', 'ipfs', 'ipns', 'ssb', 'gopher', :relative].freeze

    CLASS_WHITELIST_TRANSFORMER = lambda do |env|
      node = env[:node]
      class_list = node['class']&.split(/[\t\n\f\r ]/)

      return unless class_list

      class_list.keep_if do |e|
        next true if e =~ /^(h|p|u|dt|e)-/ # microformats classes
        next true if e =~ /^(mention|hashtag)$/ # semantic classes
        next true if e =~ /^(ellipsis|invisible)$/ # link formatting classes
        next true if e =~ /^bbcode__([a-z1-6\-]+)$/ # bbcode
        next true if e == 'signature'
      end

      node['class'] = class_list.join(' ')
    end

    ANCHOR_SANITIZER = lambda do |env|
      return unless env[:node_name] == 'a'
      node = env[:node]
      return if node['href'].blank? || node.text.blank?

      class_list = node['class']&.split(/[\t\n\f\r ]/)
      return if class_list && (class_list.include?('mention') || class_list.include?('hashtag'))

      # href matches link text verbatim?
      href = node['href']
      return if href == node.text.strip

      # remove query string from link text
      node.inner_html = node.inner_html.sub(/\?\S+=\S+/, '')

      # href matches link text without query string?
      text = node.text.strip
      return if href == text

      # strip ellipse & replace keyword search obscuring
      text = text.sub(/ *(?:\u2026|\.\.\.)\Z/, '').gsub(/ dot /i, '.').gsub(/[\u200b-\u200d\ufeff\u200e\u200f]/, '')

      # href now matches text without obscuring?
      return if href == text

      # grab first url from link text
      first_url = text.scan(/[\w\-]+\.[\w\-]+(?:\.[\w\-]+)*\S*/).first

      # if there's no link in the text mark as custom text
      if first_url.nil?
        node.inner_html = "\u270d\ufe0f #{node.inner_html}"
        return
      end

      # strip trailing slashes
      text.sub!(/\/+\Z/, '')

      # href starts with link text?
      return if href.start_with?(text)

      # split href into parts & grab shortened href
      uri = Addressable::URI.parse(node['href'])
      short_href = uri.host + uri.path
      normalized_short_href = uri.normalized_host + uri.normalized_path

      # shortened href starts with link text?
      return if short_href.start_with?(text) || normalized_short_href.start_with?(text)

      # first domain in link text (if there is one) matches href domain?
      if short_href == first_url || normalized_short_href == first_url
        # link text customized by author
        node.inner_html = "\u270d\ufe0f #{node.inner_html}"
        return
      end

      # possibly misleading link text
      node.inner_html = "\u26a0\ufe0f #{node.inner_html}"
    rescue Addressable::URI::InvalidURIError, IDN::Idna::IdnaError
      # strip malformed links
      node = env[:node]
      node['href'] = '#'
      node.children.remove
      node.inner_html = "\u274c #{node.inner_html}"
    end

    QUERY_STRING_SANITIZER = lambda do |env|
      return unless %w(a blockquote embed iframe source).include?(env[:node_name])
      node = env[:node]
      ['href', 'src', 'cite'].each do |attr|
        next if node[attr].blank?
        url = Addressable::URI.parse(node[attr])
        next if url.query.blank?
        params = CGI.parse(url.query)
        params.delete_if do |key|
          k = key.downcase
          next true if k.start_with?(
            '_hs',
            'ic',
            'mc_',
            'mkt_',
            'ns_',
            'sr_',
            'utm',
            'vero_',
            'nr_',
            'ref',
          )
          next true if 'track'.in?(k)
          next true if [
            'fbclid',
            'gclid',
            'ncid',
            'ocid',
            'r',
            'spm',
          ].include?(k)
          false
        end
        url.query = URI.encode_www_form(params)
        node[attr] = url
      end
    end

    MASTODON_STRICT ||= freeze_config(
      elements: %w(p br span a abbr del pre sub sup blockquote code b strong u i em h1 h2 h3 h4 h5 h6 ul ol li hr),

      attributes: {
        'a'          => %w(href rel class title alt),
        'span'       => %w(class),
        'abbr'       => %w(title),
        'blockquote' => %w(cite),
        'p'          => %w(class),
      },

      add_attributes: {
        'a' => {
          'rel' => 'nofollow noopener',
          'target' => '_blank',
        },
      },

      protocols: {
        'a'          => { 'href' => HTTP_PROTOCOLS },
        'blockquote' => { 'cite' => HTTP_PROTOCOLS },
      },

      transformers: [
        CLASS_WHITELIST_TRANSFORMER,
        QUERY_STRING_SANITIZER,
        ANCHOR_SANITIZER
      ]
    )

    MASTODON_OEMBED ||= freeze_config merge(
      RELAXED,
      elements: RELAXED[:elements] + %w(audio embed iframe source video),

      attributes: merge(
        RELAXED[:attributes],
        'audio'  => %w(controls),
        'embed'  => %w(height src type width),
        'iframe' => %w(allowfullscreen frameborder height scrolling src width),
        'source' => %w(src type),
        'video'  => %w(controls height loop width),
        'div'    => [:data]
      ),

      protocols: merge(
        RELAXED[:protocols],
        'embed'  => { 'src' => HTTP_PROTOCOLS },
        'iframe' => { 'src' => HTTP_PROTOCOLS },
        'source' => { 'src' => HTTP_PROTOCOLS }
      ),

      transformers: [QUERY_STRING_SANITIZER]
    )
  end
end
