module UrlHelper
  def sanitize_query_string(url)
    return if url.blank?
    url = Addressable::URI.parse(url)
    return url.to_s if url.query.blank?
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
    return url.to_s
  rescue Addressable::URI::InvalidURIError, IDN::Idna::IdnaError
    return '#'
  end
end
