doc = Ox::Document.new(version: '1.0')

doc << Ox::Element.new('XRD').tap do |xrd|
  xrd['xmlns'] = 'http://docs.oasis-open.org/ns/xri/xrd-1.0'

  xrd << (Ox::Element.new('Subject') << @account.to_webfinger_s)


  if @account.instance_actor?
    xrd << (Ox::Element.new('Alias') << instance_actor_url)

    xrd << Ox::Element.new('Link').tap do |link|
      link['rel']      = 'http://webfinger.net/rel/profile-page'
      link['type']     = 'text/html'
      link['href']     = about_more_url(instance_actor: true)
    end

    xrd << Ox::Element.new('Link').tap do |link|
      link['rel']      = 'self'
      link['type']     = 'application/activity+json'
      link['href']     = instance_actor_url
    end
  else
    xrd << (Ox::Element.new('Alias') << short_account_url(@account))
    xrd << (Ox::Element.new('Alias') << account_url(@account))

    xrd << Ox::Element.new('Link').tap do |link|
      link['rel']      = 'http://webfinger.net/rel/profile-page'
      link['type']     = 'text/html'
      link['href']     = short_account_url(@account)
    end

    xrd << Ox::Element.new('Link').tap do |link|
      link['rel']      = 'self'
      link['type']     = 'application/activity+json'
      link['href']     = account_url(@account)
    end
  end
end

('<?xml version="1.0" encoding="UTF-8"?>' + Ox.dump(doc, effort: :tolerant)).force_encoding('UTF-8')
