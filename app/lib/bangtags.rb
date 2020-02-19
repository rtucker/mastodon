# frozen_string_literal: true

class Bangtags
  include ModerationHelper
  include ServiceAccountHelper

  attr_reader :status, :account

  def initialize(status)
    @status        = status
    @account       = status.account
    @user          = @account.user
    @parent_status = Status.find(status.in_reply_to_id) if status.in_reply_to_id

    @crunch_newlines = false
    @once = false
    @sroff_open = false
    @strip_lines = false

    @prefix_ns = {
      'permalink' => ['link'],
      'cloudroot' => ['link'],
      'blogroot' => ['link'],

      'leave' => ['thread'],
      'part' => ['thread'],
      'quit' => ['thread'],
      'kick' => ['thread'],
      'unkick' => ['thread'],

      'publish' => ['parent'],
    }

    @aliases = {
      %w(media end) => %w(var end),
      %w(media stop) => %w(var end),
      %w(media endall) => %w(var endall),
      %w(media stopall) => %w(var endall),

      %w(admin end) => %w(var end),
      %w(admin stop) => %w(var end),
      %w(admin endall) => %w(var endall),
      %w(admin stopall) => %w(var endall),

      %w(parent visibility) => %w(visibility parent),
      %w(parent v) => %w(visibility parent),
      %w(parent kick) => %w(thread kick),
      %w(parent unkick) => %w(thread unkick),

      %w(parent l) => %w(live parent),
      %w(parent live) => %w(live parent),
      %w(parent lifespan) => %w(lifespan parent),
      %w(parent delete_in) => %w(delete_in parent),

      %w(thread l) => %w(l thread),
      %w(thread live) => %w(live thread),
      %w(thread lifespan) => %w(lifespan thread),
      %w(thread delete_in) => %w(delete_in thread),

      %w(all l) => %w(l all),
      %w(all live) => %w(live all),
      %w(all lifespan) => %w(lifespan all),
      %w(all delete_in) => %w(delete_in all),

      %w(parent d) => %w(defederate_in parent),
      %w(parent defed) => %w(defederate_in parent),
      %w(parent defed_in) => %w(defederate_in parent),
      %w(parent defederate) => %w(defederate_in parent),

      %w(thread d) => %w(defederate_in thread),
      %w(thread defed) => %w(defederate_in thread),
      %w(thread defed_in) => %w(defederate_in thread),
      %w(thread defederate) => %w(defederate_in thread),

      %w(all d) => %w(defederate_in all),
      %w(all defed) => %w(defederate_in all),
      %w(all defed_in) => %w(defederate_in all),
      %w(all defederate) => %w(defederate_in all),
    }

    # sections of the final status text
    @chunks = []
    # list of transformation commands
    @tf_cmds = []
    # list of post-processing commands
    @post_cmds = []
    # hash of bangtag variables
    @vars = @user.vars
    # keep track of what variables we're appending the value of between chunks
    @vore_stack = []
    # keep track of what type of nested components are active so we can !end them in order
    @component_stack = []
  end

  def process
    return unless !@vars['_bangtags:disable'] && status.text&.present? && status.text&.include?('#!')

    status.text.gsub!('#!!', "#\ufdd6!")
    @vars.delete('_bangtags:skip') if @vars['_bangtags:skip']

    status.text.split(/(#!(?:.*:!#|{.*?}|[^\s#]+))/).each do |chunk|
      if @vore_stack.last == '_draft' || (@chunks.present? && status.draft?)
        chunk.gsub("#\ufdd6!", '#!')
        @chunks << chunk
        next
      end

      next unless chunk.starts_with?('#!')

      orig_chunk = chunk
      chunk.sub!(/(\\:)?+:+?!#\Z/, '\1')
      chunk.sub!(/{(.*)}\Z/, '\1')
      chunk.strip!

      if @vore_stack.last == '_comment'
        if chunk.in?(['#!comment:end', '#!comment:stop', '#!comment:endall', '#!comment:stopall'])
          @vore_stack.pop
          @component_stack.pop
        end

        next
      elsif @vars['_bangtags:off'] || @vars['_bangtags:skip']
        if chunk.in?(['#!bangtags:on', '#!bangtags:enable'])
          @vars.delete('_bangtags:off')
          @vars.delete('_bangtags:skip')
          next
        end

        @chunks << orig_chunk.gsub("#\ufdd6!", '#!')
        next
      else
        cmd = chunk[2..-1].strip
        next if cmd.blank?

        cmd = cmd.split(':::')
        cmd = cmd[0].split('::') + cmd[1..-1]
        cmd = cmd[0].split(':') + cmd[1..-1]

        cmd.map! { |c| c.gsub(/\\:/, ':').gsub(/\\\\:/, '\:') }

        prefix = @prefix_ns[cmd[0]]
        cmd = prefix + cmd unless prefix.nil?

        @aliases.each_key do |old_cmd|
          cmd = @aliases[old_cmd] + cmd.drop(old_cmd.length) if cmd.take(old_cmd.length) == old_cmd
        end
      end

      next if cmd[0].nil?

      if cmd[0].downcase == 'once'
        @once = true
        cmd.shift
        next if cmd[0].nil?
      end

      case cmd[0].downcase
      when 'bangtags'
        chunk = nil
        next if cmd[1].nil?

        case cmd[1].downcase
        when 'off', 'disable'
          @vars['_bangtags:off'] = true
          next
        when 'skip'
          @vars['_bangtags:skip'] = true
          next
        when 'break'
          break
        end

      when 'var'
        chunk = nil
        next if cmd[1].nil?

        case cmd[1].downcase

        when 'end', 'stop'
          @vore_stack.pop
          @component_stack.pop

        when 'endall', 'stopall'
          @vore_stack = []
          @component_stack.reject! { |c| c == :var }
        else
          var = cmd[1]
          next if var.nil? || var.starts_with?('_')

          new_value = cmd[2..-1]
          if new_value.blank?
            chunk = @vars[var]
          elsif new_value.length == 1 && new_value[0] == '-'
            @vore_stack.push(var)
            @component_stack.push(:var)
          else
            @vars[var] = new_value.join(':')
          end
        end

      when 'strip'
        chunk = nil
        @strip_lines = cmd[1]&.downcase.in?(['y', 'yes', '', nil])

      when 'tf'
        chunk = nil
        next if cmd[1].nil?

        case cmd[1].downcase

        when 'end', 'stop'
          @tf_cmds.pop
          @component_stack.pop

        when 'endall', 'stopall'
          @tf_cmds = []
          @component_stack.reject! { |c| c == :tf }
        else
          @vars['_tf:head:count'] = 0 if cmd[1].downcase.in?(%w(head take))
          @tf_cmds.push(cmd[1..-1])
          @component_stack.push(:tf)
        end

      when 'end', 'stop'
        chunk = nil
        case @component_stack.pop

        when :tf
          @tf_cmds.pop

        when :var, :hide
          @vore_stack.pop
        end

      when 'endall', 'stopall'
        chunk = nil
        @tf_cmds = []
        @vore_stack = []
        @component_stack = []

      when 'emojify'
        chunk = nil
        next if cmd[1].nil?

        src_img = nil
        shortcode = cmd[2]
        case cmd[1].downcase

        when 'avatar'
          src_img = status.account.avatar

        when 'parent'
          next unless cmd[3].present? && reply?

          shortcode = cmd[3]
          next if cmd[2].nil? || @parent_status.nil?

          case cmd[2].downcase

          when 'avatar'
            src_img = @parent_status.account.avatar
          end
        end

        next if src_img.nil? || shortcode.nil? || !shortcode.match?(/\A\w+\Z/)

        chunk = ":#{shortcode}:"
        emoji = CustomEmoji.find_or_initialize_by(shortcode: shortcode, domain: nil)
        if emoji.id.nil?
          emoji.image = src_img
          emoji.save
          user_friendly_action_log(@account, :create, emoji)
        end

      when 'emoji'
        chunk = nil
        next if cmd[1].nil?

        shortcode = cmd[1]
        domain = (cmd[2].blank? ? nil : cmd[2].downcase)
        chunk = ":#{shortcode}:"
        ours = CustomEmoji.find_or_initialize_by(shortcode: shortcode, domain: nil)
        if ours.id.nil?
          theirs = if domain.nil?
                      CustomEmoji.find_by(shortcode: shortcode)
                    else
                      CustomEmoji.find_by(shortcode: shortcode, domain: domain)
                    end
          unless theirs.nil?
            ours.image = theirs.image
            ours.save
            user_friendly_action_log(@account, :create, ours)
          end
        end

      when 'char'
        chunk = nil
        charmap = {
          'zws' => "\u200b",
          'zwnj' => "\u200c",
          'zwj' => "\u200d",
          '\n' => "\n",
          '\r' => "\r",
          '\t' => "\t",
          '\T' => '    ',
        }
        cmd[1..-1].each do |c|
          next if c.nil?

          if c.in?(charmap)
            @chunks << charmap[cmd[1]]
          elsif (/^\h{1,5}$/ =~ c) && c.to_i(16) > 0
            begin
              @chunks << [c.to_i(16)].pack('U*')
            rescue StandardError
              @chunks << '?'
            end
          end
        end

      when 'link'
        chunk = nil
        next if cmd[1].nil?

        case cmd[1].downcase

        when 'permalink', 'self'
          chunk = TagManager.instance.url_for(status)

        when 'cloudroot'
          chunk = "https://monsterpit.cloud/~/#{account.username}"

        when 'blogroot'
          chunk = "https://monsterpit.blog/~/#{account.username}"
        end

      when 'ping'
        mentions = []
        next if cmd[1].nil?

        case cmd[1].downcase

        when 'admins'
          mentions = User.admins.map { |u| "@#{u.account.username}" }
          mentions.sort!

        when 'mods'
          mentions = User.moderators.map { |u| "@#{u.account.username}" }
          mentions.sort!

        when 'staff'
          mentions = User.admins.map { |u| "@#{u.account.username}" }
          mentions += User.moderators.map { |u| "@#{u.account.username}" }
          mentions.uniq!
          mentions.sort!
        end
        chunk = mentions.join(' ')

      when 'tag'
        chunk = nil
        tags = cmd[1..-1].map { |t| t.gsub(':', '.') }
        add_tags(status, *tags)

      when '10629'
        chunk = "\u200b:gargamel:\u200b I really don't think we should do this."

      when 'thread'
        chunk = nil
        next if cmd[1].nil?

        case cmd[1].downcase

        when 'leave', 'part', 'quit'
          next if status.conversation_id.nil?

          @account.mute_conversation!(status.conversation)
          if %w(replyguy reply-guy reply-guy-mode).include?(cmd[2])
            rum = Account.find_remote('RumPartov', 'weirder.earth')
            next if rum.blank?

            rum.mentions.where(status: status).first_or_create(status: status)
          end

        when 'kick'
          next if cmd[2].blank? && @parent_status.nil?

          convo_statuses = status.conversation.statuses.reorder(:id)
          first = convo_statuses.first
          next if status.conversation_id.nil? || first.account_id != @account.id

          if cmd[2].present?
            cmd[2] = cmd[2][1..-1] if cmd[2].start_with?('@')
            cmd[2], cmd[3] = cmd[2].split('@', 2) if cmd[2].include?('@')
            cmd[3] = cmd[3].strip unless cmd[3].nil?
            parent_account = Account.find_by(username: cmd[2].strip, domain: cmd[3])
          else
            next if @parent_status.nil?

            parent_account = @parent_status.account
          end
          next if parent_account.nil? || parent_account.id == @account.id

          ConversationKick.find_or_create_by(account_id: parent_account.id, conversation_id: status.conversation_id)
          convo_statuses.where(account_id: parent_account.id).find_each do |s|
            RemoveStatusForAccountService.new.call(@account, s)
          end
          service_dm(
            'janitor', @account,
            "Kicked @#{parent_account.acct} from [thread #{status.conversation_id}](#{TagManager.instance.url_for(first)}).",
            footer: '#!thread:kick'
          )

        when 'unkick'
          next if cmd[2].blank? && @parent_status.nil?

          convo_statuses = status.conversation.statuses.reorder(:id)
          first = convo_statuses.first
          next if status.conversation_id.nil? || first.account_id != @account.id

          if cmd[2].present?
            cmd[2] = cmd[2][1..-1] if cmd[2].start_with?('@')
            cmd[3] = cmd[3].strip unless cmd[3].nil?
            parent_account = Account.find_by(username: cmd[2].strip, domain: cmd[3])
          else
            next if @parent_status.nil?

            parent_account = @parent_status.account
          end
          next if parent_account.nil? || parent_account.id == @account.id

          ConversationKick.where(account_id: parent_account.id, conversation_id: status.conversation_id).destroy_all
          service_dm(
            'janitor', @account,
            "Allowed @#{parent_account.acct} back into [thread ##{status.conversation_id}](#{TagManager.instance.url_for(first)}).",
            footer: '#!thread:unkick'
          )

        when 'reall'
          if status.conversation_id.present?
            participants = Status.where(conversation_id: status.conversation_id)
                                  .pluck(:account_id).uniq.without(@account.id)
            participants = Account.where(id: participants)
                                  .pluck(:username, :domain)
                                  .map { |a| "@#{a.compact.join('@')}" }
            participants = (cmd[2..-1].map(&:strip) | participants) unless cmd[2].nil?
            chunk = participants.join(' ')
          end

        when 'sharekey'
          next if cmd[2].nil?

          case cmd[2].downcase

          when 'revoke'
            if status.conversation_id.present?
              roars = Status.where(conversation_id: status.conversation_id, account_id: @account.id)
              roars.each do |roar|
                if roar.sharekey.present?
                  roar.sharekey = nil
                  Rails.cache.delete("statuses/#{roar.id}")
                end
              end
            end

          when 'sync', 'new'
            if status.conversation_id.present?
              roars = Status.where(conversation_id: status.conversation_id, account_id: @account.id)
              earliest_roar = roars.last # The results are in reverse-chronological order.
              if cmd[2] == 'new' || earliest_roar.sharekey.blank?
                sharekey = SecureRandom.urlsafe_base64(32)
                earliest_roar.sharekey = sharekey
                Rails.cache.delete("statuses/#{earliest_roar.id}")
              else
                sharekey = earliest_roar.sharekey.key
              end
              roars.each do |roar|
                if roar.sharekey.nil? || roar.sharekey.key != sharekey
                  roar.sharekey = sharekey
                  Rails.cache.delete("statuses/#{roar.id}")
                end
              end
            else
              status.sharekey = SecureRandom.urlsafe_base64(32)
              Rails.cache.delete("statuses/#{status.id}")
            end
          end

        when 'emoji'
          next if status.conversation_id.nil?

          roars = Status.where(conversation_id: status.conversation_id)
          roars.each do |roar|
            roar.emojis.each do |theirs|
              ours = CustomEmoji.find_or_initialize_by(shortcode: theirs.shortcode, domain: nil)
              next unless ours.id.nil?

              ours.image = theirs.image
              ours.save
              user_friendly_action_log(@account, :create, ours)
            end
          end

        when 'noreplies', 'noats', 'close'
          next if status.conversation_id.nil?

          roars = Status.where(conversation_id: status.conversation_id, account_id: @account.id)
          roars.each do |roar|
            roar.reject_replies = true
            roar.save
            Rails.cache.delete("statuses/#{roar.id}")
          end

        when 'fetch', 'refetch'
          next if status.conversation_id.nil?

          Status.where(conversation_id: status.conversation_id).pluck(:id).uniq.each do |acct_id|
            FetchAvatarWorker.perform_async(acct_id)
          end
          media_ids = Status.where(conversation_id: status.conversation_id).joins(:media_attachments).distinct(:id).pluck(:id)
          BatchFetchMediaWorker.perform_async(media_ids) unless media_ids.empty?
        end

      when 'parent'
        chunk = nil
        next if cmd[1].nil? || @parent_status.nil?

        case cmd[1].downcase

        when 'permalink', 'link'
          chunk = TagManager.instance.url_for(@parent_status)

        when 'tag', 'untag'
          chunk = nil
          next unless @parent_status.account.id == @account.id || @user.admin?

          tags = cmd[2..-1].map { |t| t.gsub(':', '.') }
          if cmd[1].downcase == 'tag'
            add_tags(@parent_status, *tags)
          else
            del_tags(@parent_status, *tags)
          end
          Rails.cache.delete("statuses/#{@parent_status.id}")

        when 'emoji'
          @parent_status.emojis.each do |theirs|
            ours = CustomEmoji.find_or_initialize_by(shortcode: theirs.shortcode, domain: nil)
            next unless ours.id.nil?

            ours.image = theirs.image
            ours.save
            user_friendly_action_log(@account, :create, ours)
          end

        when 'urls'
          plain = @parent_status.text.gsub(/(<br \/>|<br>|<\/p>)+/) { |match| "#{match}\n" }
          plain = ActionController::Base.helpers.strip_tags(plain)
          plain.gsub!(/ dot /i, '.')
          chunk = plain.scan(/https?:\/\/[\w\-]+\.[\w\-]+(?:\.[\w\-]+)*/).uniq.join(' ')

        when 'domains'
          plain = @parent_status.text.gsub(/(<br \/>|<br>|<\/p>)+/) { |match| "#{match}\n" }
          plain = ActionController::Base.helpers.strip_tags(plain)
          plain.gsub!(/ dot /i, '.')
          chunk = plain.scan(/[\w\-]+\.[\w\-]+(?:\.[\w\-]+)*/).uniq.join(' ')

        when 'noreplies', 'noats', 'close'
          next unless @parent_status.account.id == @account.id || @user.admin?

          @parent_status.reject_replies = true
          @parent_status.save
          Rails.cache.delete("statuses/#{@parent_status.id}")

        when 'bookmark', 'bm'
          Bookmark.find_or_create_by!(account: @account, status: @parent_status)
          next if @parent_status.curated || !@parent_status.distributable?
          next if @parent_status.reply? && @status.in_reply_to_account_id != @account.id

          @parent_status.update(curated: true)
          FanOutOnWriteService.new.call(@parent_status)

        when 'fetch', 'refetch'
          chunk = nil
          media_ids = @parent_status.media_attachments.pluck(:id)
          BatchFetchMediaWorker.perform_async(media_ids) unless media_ids.empty?
          FetchAvatarWorker.perform_async(@parent_status.account.id)

        when 'publish'
          chunk = nil
          del_tags(@parent_status, 'self.draft', 'draft')
          Bangtags.new(@parent_status).process
          PostStatusWorker.perform_async(@parent_status.id, hidden: false, process_mentions: true)
        end

      when 'media'
        chunk = nil

        media_idx = cmd[1]
        media_cmd = cmd[2]
        media_args = cmd[3..-1]

        next unless media_cmd.present? && media_idx.present? && media_idx.scan(/\D/).empty?

        media_idx = media_idx.to_i
        next if status.media_attachments[media_idx - 1].nil?

        case media_cmd.downcase

        when 'desc'
          if media_args.present?
            @vars["_media:#{media_idx}:desc"] = media_args.join(':')
          else
            @vars.delete("_media:#{media_idx}:desc")
            @vore_stack.push("_media:#{media_idx}:desc")
            @component_stack.push(:var)
          end
        end

        @post_cmds.push(['media', media_idx, media_cmd])

      when 'bangtag'
        chunk = orig_chunk.sub('bangtag:', '').gsub(':', ":\u200b")

      when 'join'
        chunk = nil
        next if cmd[1].nil?

        charmap = {
          'zws' => "\u200b",
          'zwnj' => "\u200c",
          'zwj' => "\u200d",
          '\n' => "\n",
          '\r' => "\r",
          '\t' => "\t",
          '\T' => '    ',
        }
        sep = charmap[cmd[1]]
        chunk = cmd[2..-1].join(sep.nil? ? cmd[1] : sep)

      when 'hide'
        chunk = nil
        next if cmd[1].nil?

        case cmd[1].downcase

        when 'end', 'stop', 'endall', 'stopall'
          @vore_stack.reject! { |v| v == '_' }
          @compontent_stack.reject! { |c| c == :hide }
        else
          if cmd[1].nil? && !'_'.in?(@vore_stack)
            @vore_stack.push('_')
            @component_stack.push(:hide)
          end
        end

      when 'comment'
        chunk = nil
        if cmd[1].nil?
          @vore_stack.push('_comment')
          @component_stack.push(:var)
        end

      when 'i', 'we'
        chunk = nil
        cmd.shift
        c = cmd.shift
        next if c.nil?

        case c.downcase

        when 'am', 'are'
          if cmd[0].blank?
            @vars.delete('_they:are')
            status.footer = nil
            next
          elsif cmd[0] == 'not'
            cmd.each do |name|
              name = name.downcase.gsub(/\s+/, '')
              @vars.delete("_they:are:#{name}")
              next unless @vars['_they:are'] == name

              @vars.delete('_they:are')
              status.footer = nil
            end
            next
          elsif cmd[0] == 'list'
            @status.visibility = :direct
            @status.local_only = true
            @status.content_type = 'text/markdown'
            names = @vars.keys.select { |k| k.start_with?('_they:are:') }
            names.delete('_they:are:_several')
            names.map! { |k| "<code>#{k[10..-1]}</code> is <em>#{@vars[k]}</em>" }
            @chunks << (["\n# <code>#!</code><code>i:am:list</code>:\n<br />\n"] + names).join("\n") + "\n"
            next
          end
          if cmd.include?('and')
            name = '_several'
            cmd.delete('and')
            cmd.map! { |who| @vars["_they:are:#{who.downcase.gsub(/\s+/, '').strip}"] }
            cmd.delete(nil)
            if cmd.count == 1
              name = who.downcase.gsub(/\s+/, '').strip
              @vars["_they:are:#{name}"] = cmd[0]
            else
              last = cmd.pop
              @vars["_they:are:#{name}"] = "#{cmd.join(', ')} and #{last}"
            end
          else
            who = cmd[0]
            if @once
              next if post_as(who.strip)
            else
              next if switch_account(who.strip)
            end
            name = who.downcase.gsub(/\s+/, '').strip
            description = cmd[1..-1].join(':').strip
            if description.blank?
              @vars["_they:are:#{name}"] = who.strip if @vars["_they:are:#{name}"].nil?
            else
              @vars["_they:are:#{name}"] = description
            end
          end

          @vars['_they:are'] = name unless @once
          status.footer = @vars["_they:are:#{name}"]
        end

      when 'sharekey'
        next if cmd[1].nil?

        case cmd[1].downcase

        when 'new'
          chunk = nil
          status.sharekey = SecureRandom.urlsafe_base64(32)
        end

      when 'draft'
        chunk = nil
        @status.hidden = true
        @status.keep_hidden!
        @vore_stack.push('_draft')
        @component_stack.push(:var)
        add_tags(status, 'self.draft')

      when 'hidden'
        chunk = nil
        @status.hidden = true
        @status.keep_hidden!

      when 'format', 'type'
        chunk = nil
        next if cmd[1].nil?

        content_types = {
          't' => 'text/plain',
          'txt' => 'text/plain',
          'text' => 'text/plain',
          'plain' => 'text/plain',
          'plaintext' => 'text/plain',

          'c' => 'text/console',
          'console' => 'text/console',
          'terminal' => 'text/console',
          'monospace' => 'text/console',

          'm' => 'text/markdown',
          'md' => 'text/markdown',
          'markdown' => 'text/markdown',

          'b' => 'text/x-bbcode',
          'bbc' => 'text/x-bbcode',
          'bbcode' => 'text/x-bbcode',

          'd' => 'text/x-bbcode+markdown',
          'bm' => 'text/x-bbcode+markdown',
          'bbm' => 'text/x-bbcode+markdown',
          'bbdown' => 'text/x-bbcode+markdown',

          'h' => 'text/html',
          'htm' => 'text/html',
          'html' => 'text/html',
        }
        v = cmd[1].downcase
        status.content_type = content_types[c] unless content_types[c].nil?

      when 'visibility', 'v'
        chunk = nil
        next if cmd[1].nil?

        visibilities = {
          'direct' => :direct,
          'dm' => :direct,
          'whisper' => :direct,
          'd' => :direct,

          'private' => :private,
          'packmate' => :private,
          'group' => :private,
          'f' => :private,
          'g' => :private,

          'unlisted' => :unlisted,
          'u' => :unlisted,

          'local' => :local,
          'monsterpit' => :local,
          'community' => :local,
          'c' => :local,
          'l' => :local,
          'm' => :local,

          'public' => :public,
          'world' => :public,
          'p' => :public,
        }
        allowed_visibility_changes = {
          'unlisted' => [:local],
          'local' => [:unlisted],
        }
        if cmd[1].downcase == 'parent'
          next unless cmd[2].present? && @parent_status.present? && @parent_status.account_id == @account.id

          v = visibilities[cmd[2].downcase]
          o = @parent_status.visibility
          next if v.nil? || allowed_visibility_changes[o].nil?
          next unless allowed_visibility_changes[o].include?(v)

          @parent_status.visibility = v
          @parent_status.local_only = false if cmd[3].downcase.in? %w(federate f public p world)
          @parent_status.save
          Rails.cache.delete("statuses/#{@parent_status.id}")
          DistributionWorker.perform_async(@parent_status.id)
          ActivityPub::DistributionWorker.perform_async(@parent_status.id) unless @parent_status.local_only?
        else
          v = cmd[1].downcase
          status.visibility = visibilities[v] unless visibilities[v].nil?
          case cmd[2]&.downcase

          when 'federate', 'f', 'public', 'p', 'world'
            status.local_only = false

          when 'nofederate', 'nf', 'localonly', 'lo', 'local', 'l', 'monsterpit', 'm', 'community', 'c'
            status.local_only = true
          end
        end

      when 'noreplies', 'noats'
        chunk = nil
        @status.reject_replies = true

      when 'live', 'lifespan', 'l', 'delete_in'
        chunk = nil
        next if cmd[1].nil?

        case cmd[1].downcase

        when 'parent', 'thread', 'all'
          s = cmd[1].downcase.to_sym
          s = @parent_status if s == :parent
          next unless s == :all || @parent_status.present?
          next unless s == :thread || s == :all || @parent_status.account_id == @account.id

          i = cmd[2].to_i
          unit = cmd[3].present? ? cmd[3].downcase : 'minutes'
        else
          s = @status
          i = cmd[1].to_i
          unit = cmd[2].present? ? cmd[2].downcase : 'minutes'
        end
        delete_after = case unit

                        when 'm', 'min', 'mins', 'minute', 'minutes'
                          i.minutes

                        when 'h', 'hr', 'hrs', 'hour', 'hours'
                          i.hours

                        when 'd', 'dy', 'dys', 'day', 'days'
                          i.days

                        when 'w', 'wk', 'wks', 'week', 'weeks'
                          i.weeks

                        when 'mn', 'mns', 'month', 'months'
                          i.months

                        when 'y', 'yr', 'yrs', 'year', 'years'
                          i.years
                        end
        if s == :thread
          @parent_status.conversation.statuses.where(account_id: @account.id).find_each do |s|
            s.delete_after = delete_after
            Rails.cache.delete("statuses/#{s.id}")
          end
        elsif s == :all
          @account.statuses.find_each do |s|
            s.delete_after = delete_after
            Rails.cache.delete("statuses/#{s.id}")
          end
        else
          s.delete_after = delete_after
          Rails.cache.delete("statuses/#{s.id}")
        end

      when 'd', 'defed', 'defed_in', 'defederate', 'defederate_in'
        chunk = nil
        next if cmd[1].nil?

        case cmd[1].downcase

        when 'parent', 'thread', 'all'
          s = cmd[1].downcase.to_sym
          s = @parent_status if s == :parent
          next unless s == :all || @parent_status.present?
          next unless s == :thread || s == :all || @parent_status.account_id == @account.id

          i = cmd[2].to_i
          unit = cmd[3].present? ? cmd[3].downcase : 'minutes'
        else
          s = @status
          i = cmd[1].to_i
          unit = cmd[2].present? ? cmd[2].downcase : 'minutes'
        end
        defederate_after = case unit

                            when 'm', 'min', 'mins', 'minute', 'minutes'
                              i.minutes

                            when 'h', 'hr', 'hrs', 'hour', 'hours'
                              i.hours

                            when 'd', 'dy', 'dys', 'day', 'days'
                              i.days

                            when 'w', 'wk', 'wks', 'week', 'weeks'
                              i.weeks

                            when 'mn', 'mns', 'month', 'months'
                              i.months

                            when 'y', 'yr', 'yrs', 'year', 'years'
                              i.years
                            end
        if s == :thread
          @parent_status.conversation.statuses.where(account_id: @account.id).find_each do |s|
            s.defederate_after = defederate_after
            Rails.cache.delete("statuses/#{s.id}")
          end
        elsif s == :all
          @account.statuses.find_each do |s|
            s.defederate_after = defederate_after
            Rails.cache.delete("statuses/#{s.id}")
          end
        else
          s.defederate_after = defederate_after
          Rails.cache.delete("statuses/#{s.id}")
        end

      when 'keysmash'
        keyboard = [
          'asdf', 'jkl;',
          'gh', "'",
          'we', 'io',
          'r', 'u',
          'cv', 'nm',
          't', 'x', ',',
          'q', 'z',
          'y', 'b',
          'p', '[',
          '.', '/',
          ']', '\\'
        ]

        chunk = rand(6..33).times.map do
          keyboard[(keyboard.size * (rand**3)).floor].split('').sample
        end
        chunk = chunk.join

      when 'nosr', 'sroff', 'srskip'
        next if @sroff_open

        @sroff_open = true
        chunk = "\ufdd3"

      when 'sr', 'sron', 'srcont'
        next unless @sroff_open

        @sroff_open = false
        chunk = "\ufdd4"

      when 'histogram'
        @status.content_type = 'text/html'
        barchars = " #{(0x2588..0x258F).to_a.reverse.pack('U*')}"
        q = cmd[1..-1].join.strip
        next if q.blank?

        begin
          data = @account.statuses.search(q.unaccent)
                          .reorder(:created_at)
                          .pluck(:created_at)
                          .map { |d| d.strftime('%Y-%m') }
                          .each_with_object(Hash.new(0)) { |v, h| h.store(v, h[v] + 1); }
        rescue ActiveRecord::StatementInvalid
          raise Mastodon::ValidationError, 'Invalid query.'
        end
        highest = data.values.max
        avg = "<code>average: #{data.values.sum / data.count}</code>"
        total = "<code>\u200c \u200c total: #{data.values.sum}</code>"
        data = data.map do |date, count|
          fill = count / highest.to_f * 96
          bar = "#{"\u2588" * (fill / 8).to_i}#{barchars[fill % 8]}"
          "<code>#{date}: #{bar} #{count}</code>"
        end
        chunk = "<p>\"<code>#{q.split('').join("\u200c")}</code>\" mentions by post count:<br/>#{data.join('<br/>')}<br/>#{avg}<br/>#{total}</p>"

      when 'op', 'oper', 'fang', 'fangs'
        chunk = nil
        next unless @user.can_moderate? && @user.defanged?
        @user.fangs_out!
        service_dm('announcements', @account, "You are now in #{@user.role} mode. This will expire after 15 minutes.", footer: '#!fangs')

      when 'deop', 'deoper', 'defang'
        chunk = nil
        next if @user.defanged?
        @user.defang!
        service_dm('announcements', @account, "You are no longer in #{@user.role} mode.", footer: '#!defang')


      when 'admin'
        chunk = nil
        next unless @user.admin? && !@user.defanged?
        next if cmd[1].nil?

        @status.visibility = :direct
        @status.local_only = true
        add_tags(@status, 'monsterpit.admin.log')
        @status.content_type = 'text/markdown'
        @chunks << "\n# <code>#!</code><code>admin:#{cmd[1].downcase}</code>:\n<br/>\n"
        case cmd[1].downcase

        when 'silence', 'unsilence', 'suspend', 'unsuspend', 'force_unlisted', 'allow_public', 'force_sensitive', 'allow_nonsensitive', 'reset', 'forgive'
          @status.spoiler_text = "admin #{cmd[1].downcase}" if @status.spoiler_text.blank?
          @tf_cmds.push(cmd)
          @component_stack.push(:tf)

        when 'exec', 'eval'
          unless @account.username.in?((ENV['ALLOW_ADMIN_EVAL_FROM'] || '').split)
            @chunks << '<em>Unauthorized.</em>'
            next
          end
          unless cmd[2].present? && cmd[2].downcase == 'last'
            @vars.delete('_admin:eval')
            @vore_stack.push('_admin:eval')
            @component_stack.push(:var)
          end
          @post_cmds.push(%w(admin eval))

        when 'announce'
          @vars.delete('_admin:announce')
          @vore_stack.push('_admin:announce')
          @component_stack.push(:var)
          c = %w(admin announce)
          c << 'local' if cmd[2].present? && cmd[2].downcase == 'local'
          @post_cmds.push(c)

        when 'unannounce'
          @tf_cmds.push(cmd)
          @component_stack.push(:tf)
        end

      when 'account'
        chunk = nil
        cmd.shift
        c = cmd.shift
        next if c.nil?

        @status.visibility = :direct
        @status.local_only = true
        @status.content_type = 'text/markdown'
        @status.delete_after = 1.hour
        @chunks << "\n# <code>#!</code><code>account:#{c.downcase}</code>:\n<br />\n"
        output = []
        case c.downcase

        when 'link'
          c = cmd.shift
          next if c.nil?

          case c.downcase

          when 'add'
            target = cmd.shift
            token = cmd.shift
            if target.blank? || token.blank?
              output << "\u274c Missing account parameter." if target.blank?
              output << "\u274c Missing token parameter." if token.blank?
              break
            end
            target_acct = Account.find_local(target)
            if target_acct&.user.nil? || target_acct.id == @account.id
              output << "\u274c Invalid account."
              break
            end
            unless token == target_acct.user.vars['_account:link:token']
              output << "\u274c Invalid token."
              break
            end
            target_acct.user.vars['_account:link:token'] = nil
            target_acct.user.save
            LinkedUser.find_or_create_by!(user_id: @user.id, target_user_id: target_acct.user.id)
            LinkedUser.find_or_create_by!(user_id: target_acct.user.id, target_user_id: @user.id)
            output << "\u2705 Linked with <strong>@\u200c#{target}</strong>."

          when 'del', 'delete'
            cmd.each do |target|
              target_acct = Account.find_local(target)
              next if target_acct&.user.nil? || target_acct.id == @account.id

              LinkedUser.where(user_id: @user.id, target_user_id: target_acct.user.id).destroy_all
              LinkedUser.where(user_id: target_acct.user.id, target_user_id: @user.id).destroy_all
              output << "\u2705 <strong>@\u200c#{target}</strong> unlinked."
            end

          when 'clear', 'delall', 'deleteall'
            LinkedUser.where(target_user_id: @user.id).destroy_all
            LinkedUser.where(user_id: @user.id).destroy_all
            output << "\u2705 Cleared all links."

          when 'token'
            @vars['_account:link:token'] = SecureRandom.urlsafe_base64(32)
            output << 'Account link token is:'
            output << "<code>#{@vars['_account:link:token']}</code>"
            output << ''
            output << 'On the local account you want to link, paste:'
            output << "<code>#!account:link:add:#{@account.username}:#{@vars['_account:link:token']}</code>"
            output << ''
            output << 'The token can only be used once.'
            output << ''
            output << "\xe2\x9a\xa0\xef\xb8\x8f <strong>This grants full access to your account! Be careful!</strong>"

          when 'list'
            @user.linked_users.find_each do |linked_user|
              if linked_user&.account.nil?
                link.destroy
              else
                output << "\u2705 <strong>@\u200c#{linked_user.account.username}</strong>"
              end
            end
          end
        end
        output = ['<em>No action.</em>'] if output.blank?
        chunk = output.join("\n") + "\n"

      when 'queued', 'scheduled'
        chunk = nil
        next if cmd[1].nil?

        case cmd[1].downcase

        when 'boosts', 'repeats'
          output = ["# Queued boosts\n"]
          @account.queued_boosts.find_each do |q|
            s = Status.find_by(id: q.status_id)
            next if s.nil?

            output << "\\- [#{q.status_id}](#{TagManager.instance.url_for(s)})"
          end
          output << if Redis.current.exists("queued_boost:#{@account.id}")
                      "\nNext boost in #{Redis.current.ttl("queued_boost:#{@account.id}") / 60} minutes."
                    else
                      "\nNothing scheduled yet."
                    end

          service_dm('announcements', @account, output.join("\n"), footer: '#!queued:boosts')

        when 'posts', 'statuses', 'roars'
          output = ['<h1>Queued roars</h1><br>']
          @account.scheduled_statuses.find_each do |s|
            s = Status.find_by(id: s.status_id)
            next if s.nil?

            preview = s.spoiler_text || s.text
            preview = '[no body text]' if preview.blank?
            preview = preview[0..50]
            preview = html_entities.encode(preview)

            output << "- <a href=\"#{TagManager.instance.url_for(s)}\">#{preview}</a>"
          end
          service_dm('announcements', @account, output.join('<br>'), content_type: 'text/html', footer: '#!queued:posts')
        end
      end

      chunk.gsub!("#\ufdd6!", '#!') unless chunk.blank? || chunk.frozen?

      if chunk.present? && @tf_cmds.present?
        @tf_cmds.each do |tf_cmd|
          next if chunk.nil? || tf_cmd[0].nil?

          case tf_cmd[0].downcase

          when 'replace', 'sub', 's'
            tf_cmd[1..-1].in_groups_of(2) do |args|
              chunk.sub!(*args) if args.all?
            end

          when 'replaceall', 'gsub', 'gs'
            tf_cmd[1..-1].in_groups_of(2) do |args|
              chunk.gsub!(*args) if args.all?
            end

          when 'stripanchors'
            chunk.gsub!(/<a .*?<\/a>/mi, '')

          when 'striplinks'
            chunk.gsub!(/\S+:\/\/[\w\-]+\.\S+/, '')
            chunk = ActionController::Base.helpers.strip_links(chunk)

          when 'head', 'take'
            n = tf_cmd[1].to_i
            n = 1 unless n > 0
            next if @vars['_tf:head:count'] == n

            c = @vars['_tf:head:count'] || 0
            parts = chunk.split.take(n - c)
            @vars['_tf:head:full'] = c + parts.count
            chunk = parts.join(' ')

          when 'admin'
            next unless @user.admin?
            next if tf_cmd[1].nil? || chunk.start_with?('`admin:')

            output = []
            action = tf_cmd[1].downcase
            case action

            when 'unannounce'
              announcer = ENV['ANNOUNCEMENTS_USER'].to_i
              if announcer == 0
                @chunks << '<em>No announcer set.</em>'
                next
              end
              announcer = Account.find_by(id: announcer)
              if announcer.blank?
                @chunks << '<em>Announcer account missing.</em>'
                next
              end
              chunk.split.each do |c|
                c.scan('\d+$').each do |status_id|
                  s = Status.find_by(id: status_id.to_i)
                  if s.nil?
                    output << "<em>Skipped</em> non-existing ID <code>#{status_id}</code>."
                    next
                  elsif s.account.id != announcer.id
                    output << "<em>Skipped</em> non-announcer ID <code>#{status_id}</code>."
                    next
                  end
                  output << "<strong>Removed</strong> announcement ID <code>#{status_id}</code>."
                  RemoveStatusService.new.call(s)
                end
              end

            when 'silence', 'unsilence', 'suspend', 'unsuspend', 'force_unlisted', 'allow_public', 'force_sensitive', 'allow_nonsensitive', 'reset', 'forgive'
              action = 'reset' if action == 'forgive'
              reason = tf_cmd[2..-1].join(':')
              chunk.split.each do |c|
                if c.start_with?('@')
                  account_parts = c.split('@')[1..2]
                  successful = account_policy(account_parts[0], account_parts[1], action, reason)
                else
                  successful = domain_policy(c, action, reason)
                end
                output << if successful
                            "\u2705 <code>#{c}</code>"
                          else
                            "\u274c <code>#{c}</code>"
                          end
              end
              if output.blank?
                output = ['<em>No action.</em>']
              elsif reason.present?
                output << ''
                output << "<strong>Comment:</strong> <em>#{reason}</em>"
              end
              chunk = output.join("\n") + "\n"
            end
          end
        end
      end

      unless chunk.blank? || @vore_stack.empty?
        var = @vore_stack.last
        next if var == '_'

        if @vars[var].nil?
          @vars[var] = chunk.lstrip
        else
          @vars[var] += chunk.rstrip
        end
        chunk = nil
      end

      @chunks << chunk unless chunk.nil?
    end

    @vars.delete('_bangtags:skip') if @vars['_bangtags:skip']
    @vars.transform_values! { |v| v.rstrip if v.is_a?(String) }

    postprocess_before_save

    @user.save

    text = @chunks.join
    text.gsub!(/\n\n+/, "\n") if @crunch_newlines
    text.strip!
    text = text.split("\n").map(&:strip).join("\n") if @strip_lines

    if text.blank? || has_only_mentions?(text)
      RemoveStatusService.new.call(@status)
    else
      status.text = text
      status.save
      postprocess_after_save
    end
  end

  private

  def postprocess_before_save
    @post_cmds.each do |post_cmd|
      case post_cmd[0]

      when 'media'
        media_idx = post_cmd[1]
        media_cmd = post_cmd[2]
        media_args = post_cmd[3..-1]

        case media_cmd

        when 'desc'
          status.media_attachments[media_idx - 1].description = @vars["_media:#{media_idx}:desc"]
          status.media_attachments[media_idx - 1].save
          @vars.delete("_media:#{media_idx}:desc")
        end

      when 'admin'
        next unless @user.admin?
        next if post_cmd[1].nil?

        case post_cmd[1]

        when 'eval'
          @crunch_newlines = true
          @vars['_admin:eval'].strip!
          @chunks << "\n<strong>Input:</strong>"
          @chunks << '<pre><code>'
          @chunks << html_entities.encode(@vars['_admin:eval']).gsub("\n", '<br/>')
          @chunks << '</code></pre>'
          begin
            result = eval(@vars['_admin:eval'])
          rescue Exception => e
            result = "\u274c #{e.message}"
          end
          @chunks << '<strong>Output:</strong>'
          @chunks << '<pre><code>'
          @chunks << html_entities.encode(result).gsub("\n", '<br/>')
          @chunks << '</code></pre>'

        when 'announce'
          announcer = ENV['ANNOUNCEMENTS_USER'].to_i
          if announcer == 0
            @chunks << '<em>No announcer set.</em>'
            next
          end
          announcer = Account.find_by(id: announcer)
          if announcer.blank?
            @chunks << '<em>Announcer account missing.</em>'
            next
          end

          name = @user.vars['_they:are']
          footer = if name.present?
                     "#{@user.vars["_they:are:#{name}"]} from @#{@account.username}"
                   else
                     "@#{@account.username}"
                   end

          s = PostStatusService.new.call(
            announcer,
            visibility: :local,
            text: @vars['_admin:announce'],
            footer: footer,
            local_only: post_cmd[2] == 'local'
          )

          @chunks << 'Announce successful.'
        end
      end
    end

    @chunks << "\ufdd4" if @sroff_open
  end

  def postprocess_after_save
    @post_cmds.each do |post_cmd|
      case post_cmd[0]

      when 'mention'
        mention = @account.mentions.where(status: status).first_or_create(status: status)
      end
    end
  end

  def has_only_mentions?(text)
    text.match?(/^(?:\s*@((#{Account::USERNAME_RE})(?:@[a-z0-9\.\-]+[a-z0-9]+)?))+$/i)
  end

  def add_tags(to_status, *tags)
    valid_name = /^[[:word:]:._\-]*[[:alpha:]:._·\-][[:word:]:._\-]*$/
    tags = tags.select { |t| t.present? && valid_name.match?(t) }.uniq
    ProcessHashtagsService.new.call(to_status, tags)
    to_status.save
  end

  def del_tags(from_status, *tags)
    valid_name = /^[[:word:]:._\-]*[[:alpha:]:._·\-][[:word:]:._\-]*$/
    tags = tags.select { |t| t.present? && valid_name.match?(t) }.uniq
    tags.map { |str| str.mb_chars.downcase }.uniq(&:to_s).each do |name|
      name.gsub!(/[:.]+/, '.')
      next if name.blank? || name == '.'

      filtered_tags = if name.ends_with?('.')
                        from_status.tags.select { |t| t.name == name || t.name.starts_with?(name) }
                      else
                        from_status.tags.select { |t| t.name == name }
                      end
      from_status.tags.destroy(filtered_tags)
    end
    from_status.save
  end

  def switch_account(target_acct)
    target_acct = Account.find_local(target_acct)
    return false unless target_acct&.user.present? && target_acct.user.in?(@user.linked_users)

    Redis.current.publish("timeline:#{@account.id}", Oj.dump(event: :switch_accounts, payload: target_acct.user.id))
    true
  end

  def post_as(target_acct)
    target_acct = Account.find_local(target_acct)
    return false unless target_acct&.user.present? && target_acct.user.in?(@user.linked_users)

    status.account_id = target_acct.id
  end

  def html_entities
    @html_entities ||= HTMLEntities.new
  end
end
