# frozen_string_literal: true

class FetchAtomService < BaseService
  include JsonLdHelper
  include AutorejectHelper

  def call(url)
    return if url.blank?
    return if autoreject?(url)

    result = process(url)
  rescue OpenSSL::SSL::SSLError => e
    Rails.logger.debug "SSL error: #{e}"
    nil
  rescue HTTP::ConnectionError => e
    Rails.logger.debug "HTTP ConnectionError: #{e}"
    nil
  end

  private

  def process(url, terminal = false)
    @url = url
    perform_request { |response| process_response(response, terminal) }
  end

  def perform_request(&block)
    accept = 'application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams", text/html'

    Request.new(:get, @url).add_headers('Accept' => accept).perform(&block)
  end

  def process_response(response, terminal = false)
    return nil if response.code != 200

    if ['application/activity+json', 'application/ld+json'].include?(response.mime_type)
      body = response.body_with_limit
      json = body_to_json(body)
      if supported_context?(json) && equals_or_includes_any?(json['type'], ActivityPub::FetchRemoteAccountService::SUPPORTED_TYPES) && json['inbox'].present?
        [json['id'], { prefetched_body: body, id: true }]
      elsif supported_context?(json) && expected_type?(json)
        [json['id'], { prefetched_body: body, id: true }]
      else
        nil
      end
    elsif !terminal
      link_header = response['Link'] && parse_link_header(response)

      if link_header&.find_link(%w(rel alternate))
        process_link_headers(link_header)
      elsif response.mime_type == 'text/html'
        process_html(response)
      end
    end
  end

  def expected_type?(json)
    equals_or_includes_any?(json['type'], ActivityPub::Activity::Create::SUPPORTED_TYPES + ActivityPub::Activity::Create::CONVERTED_TYPES)
  end

  def process_html(response)
    page = Nokogiri::HTML(response.body_with_limit)

    json_link = page.xpath('//link[@rel="alternate"]').find { |link| ['application/activity+json', 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'].include?(link['type']) }

    result = process(json_link['href'], terminal: true) unless json_link.nil?
    result ||= nil
    result
  end

  def process_link_headers(link_header)
    json_link = link_header.find_link(%w(rel alternate), %w(type application/activity+json)) || link_header.find_link(%w(rel alternate), ['type', 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'])

    result = process(json_link.href, terminal: true) unless json_link.nil?
    result ||= nil
    result
  end

  def parse_link_header(response)
    LinkHeader.parse(response['Link'].is_a?(Array) ? response['Link'].first : response['Link'])
  end

  def object_uri
    nil
  end
end
