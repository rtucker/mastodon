module ServiceAccountHelper
  def service_post(service, text, options = {})
    acct = find_service_account(service)
    return if acct.nil?

    options[:text] = text
    options[:local_only] ||= true
    options[:nomentions] ||= true
    options[:content_type] ||= 'text/markdown'

    PostStatusService.new.call(acct, options.compact)
  end

  def service_dm(service, to, text, options = {})
    options[:mentions] = [to]
    options[:visibility] ||= :direct
    service_post(service, text, options)
  end

  def find_service_account(service)
    account_id = ENV["#{service.upcase}_USER"].to_i
    return if account_id == 0
    Account.find_by(id: account_id)
  end
end
