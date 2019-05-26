# frozen_string_literal: true

class Sanitize
  extend UrlHelper

  module Config
    HTTP_PROTOCOLS ||= ['http', 'https', 'dat', 'dweb', 'ipfs', 'ipns', 'ssb', 'gopher', :relative].freeze
    MEDIA_EXTENSIONS ||= %w(png apng jpg jpe jpeg mpg mpeg mpeg4 mp4 mp3 aac ogg oga ogv qt gif)

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

    IMG_TAG_TRANSFORMER = lambda do |env|
      node = env[:node]

      return unless env[:node_name] == 'img'

      node.name = 'a'

      node['href'] = node['src']
      node.content = "[🖼 #{node['alt'] || node['href']}]"
    end

    QUERY_STRING_SANITIZER = lambda do |env|
      return unless %w(a blockquote embed iframe source).include?(env[:node_name])
      node = env[:node]
      ['href', 'src', 'cite'].each do |attr|
        next if node[attr].blank?
        url = Sanitize::sanitize_query_string(node[attr])
        next if url.blank?
        node[attr] = url
      end
    end

    MASTODON_STRICT ||= freeze_config(
      elements: %w(p br span a abbr del pre sub sup blockquote code b strong u i s em h1 h2 h3 h4 h5 h6 ul ol li hr),

      attributes: {
        'a'          => %w(href rel class title alt),
        'span'       => %w(class),
        'abbr'       => %w(title),
        'blockquote' => %w(cite),
        'p'          => %w(class),
        :all         => %w(aria-hidden aria-label lang),
      },

      add_attributes: {
        'a' => {
          'rel' => 'nofollow noopener tag',
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
        IMG_TAG_TRANSFORMER,
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
