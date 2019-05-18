class ReformatLocalStatuses < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  def up
    Status.local.without_reblogs.find_each do |status|
      status.content_type = 'text/x-bbcode+markdown'
      text = status.text
      matches = text.match(/\[(right|rfloat)\][\u200c\u200b—–-]+ *(.*?)\[\/\1\]\u200c?\Z/)
      if matches
        status.footer = matches[2].strip
        text = text.sub(/\[(right|rfloat)\][\u200c\u200b—–-]+.*?\[\/\1\]\u200c?\Z/, '').rstrip
      end
      text = text.gsub(/\[(color|colorhex|hexcolor)=\w+\](.*?)\[\/\1\]/, '[b]\2[/b]')
      text = text.gsub(/\[(spin|pulse)\](.*?)\[\/\1\]/, '[b]\2[/b]')
      status.text = text unless text.blank?
      Rails.logger.info("Rewrote status ID #{status.id}")
      status.save
    end
  end
end
