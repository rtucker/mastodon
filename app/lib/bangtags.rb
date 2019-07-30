# frozen_string_literal: true

class Bangtags
  include BangtagHelper
  attr_reader :status, :account

  def initialize(status)
    @status        = status
    @account       = status.account
    @parent_status = Status.find(status.in_reply_to_id) if status.in_reply_to_id

    @crunch_newlines = false
    @once = false

    @prefix_ns = {
      'permalink' => ['link'],
      'cloudroot' => ['link'],
      'blogroot' => ['link'],
    }

    @aliases = {
      ['media', 'end'] => ['var', 'end'],
      ['media', 'stop'] => ['var', 'end'],
      ['media', 'endall'] => ['var', 'endall'],
      ['media', 'stopall'] => ['var', 'endall'],

      ['admin', 'end'] => ['var', 'end'],
      ['admin', 'stop'] => ['var', 'end'],
      ['admin', 'endall'] => ['var', 'endall'],
      ['admin', 'stopall'] => ['var', 'endall'],

      ['parent', 'visibility'] => ['visibility', 'parent'],
      ['parent', 'v'] => ['visibility', 'parent'],

      ['parent', 'l'] => ['live', 'parent'],
      ['parent', 'live'] => ['live', 'parent'],
      ['parent', 'lifespan'] => ['lifespan', 'parent'],
      ['parent', 'delete_in'] => ['delete_in', 'parent'],

      ['thread', 'l'] => ['l', 'thread'],
      ['thread', 'live'] => ['live', 'thread'],
      ['thread', 'lifespan'] => ['lifespan', 'thread'],
      ['thread', 'delete_in'] => ['delete_in', 'thread'],

      ['all', 'l'] => ['l', 'all'],
      ['all', 'live'] => ['live', 'all'],
      ['all', 'lifespan'] => ['lifespan', 'all'],
      ['all', 'delete_in'] => ['delete_in', 'all'],
    }

    # sections of the final status text
    @chunks = []
    # list of transformation commands
    @tf_cmds = []
    # list of post-processing commands
    @post_cmds = []
    # hash of bangtag variables
    @vars = account.user.vars
    # keep track of what variables we're appending the value of between chunks
    @vore_stack = []
    # keep track of what type of nested components are active so we can !end them in order
    @component_stack = []
  end

  def process
    return unless !@vars['_bangtags:disable'] && status.text&.present? && status.text.include?('#!')

    status.text.gsub!('#!!', "#\uf666!")

    status.text.split(/(#!(?:.*:!#|{.*?}|[^\s#]+))/).each do |chunk|
      if @vore_stack.last == '_draft' || (@chunks.present? && @chunks.first.include?('#!draft'))
        chunk.gsub("#\uf666!", '#!')
        @chunks << chunk
      elsif chunk.starts_with?("#!")
        chunk.sub!(/(\\:)?+:+?!#\Z/, '\1')
        chunk.sub!(/{(.*)}\Z/, '\1')

        if @vore_stack.last != '_comment'
          cmd = chunk[2..-1].strip
          next if cmd.blank?
          cmd = cmd.split(':::')
          cmd = cmd[0].split('::') + cmd[1..-1]
          cmd = cmd[0].split(':') + cmd[1..-1]

          cmd.map! {|c| c.gsub(/\\:/, ':').gsub(/\\\\:/, '\:')}

          prefix = @prefix_ns[cmd[0]]
          cmd = prefix + cmd unless prefix.nil?

          @aliases.each_key do |old_cmd|
            cmd = @aliases[old_cmd] + cmd.drop(old_cmd.length) if cmd.take(old_cmd.length) == old_cmd
          end
        elsif chunk.in?(['#!comment:end', '#!comment:stop', '#!comment:endall', '#!comment:stopall'])
          @vore_stack.pop
          @component_stack.pop
          next
        else
          next
        end

        next if cmd[0].nil?
        if cmd[0].downcase == 'once'
          @once = true
          cmd.shift
          next if cmd[0].nil?
        end

        case cmd[0].downcase
        when 'var'
          chunk = nil
          next if cmd[1].nil?
          case cmd[1].downcase
          when 'end', 'stop'
            @vore_stack.pop
            @component_stack.pop
          when 'endall', 'stopall'
            @vore_stack = []
            @component_stack.reject! {|c| c == :var}
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
        when 'tf'
          chunk = nil
          next if cmd[1].nil?
          case cmd[1].downcase
          when 'end', 'stop'
            @tf_cmds.pop
            @component_stack.pop
          when 'endall', 'stopall'
            @tf_cmds = []
            @component_stack.reject! {|c| c == :tf}
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
            if domain.nil?
              theirs = CustomEmoji.find_by(shortcode: shortcode)
            else
              theirs = CustomEmoji.find_by(shortcode: shortcode, domain: domain)
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
            '\T' => '    '
          }
          cmd[1..-1].each do |c|
            next if c.nil?
            if c.in?(charmap)
              @chunks << charmap[cmd[1]]
            elsif (/^\h{1,5}$/ =~ c) && c.to_i(16) > 0
              begin
                @chunks << [c.to_i(16)].pack('U*')
              rescue
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
          tags = cmd[1..-1].map {|t| t.gsub(':', '.')}
          add_tags(status, *tags)
        when '10629'
          chunk = "\u200b:gargamel:\u200b I really don't think we should do this."
        when 'thread'
          chunk = nil
          next if cmd[1].nil?
          case cmd[1].downcase
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
                    roar.save
                    Rails.cache.delete("statuses/#{roar.id}")
                  end
                end
              end
            when 'sync', 'new'
              if status.conversation_id.present?
                roars = Status.where(conversation_id: status.conversation_id, account_id: @account.id)
                earliest_roar = roars.last # The results are in reverse-chronological order.
                if cmd[2] == 'new' || earlist_roar.sharekey.blank?
                  sharekey = SecureRandom.urlsafe_base64(32)
                  earliest_roar.sharekey = sharekey
                  earliest_roar.save
                  Rails.cache.delete("statuses/#{earliest_roar.id}")
                else
                  sharekey = earliest_roar.sharekey
                end
                roars.each do |roar|
                  if roar.sharekey != sharekey
                    roar.sharekey = sharekey
                    roar.save
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
            roars = Status.where(conversation_id: status.conversation_id, account_id: @account.id)
            roars.each do |roar|
              roar.emojis.each do |theirs|
                ours = CustomEmoji.find_or_initialize_by(shortcode: theirs.shortcode, domain: nil)
                if ours.id.nil?
                  ours.image = theirs.image
                  ours.save
                  user_friendly_action_log(@account, :create, ours)
                end
              end
            end
          end
        when 'parent'
          chunk = nil
          next if cmd[1].nil? || @parent_status.nil?
          case cmd[1].downcase
          when 'permalink', 'link'
            chunk = TagManager.instance.url_for(@parent_status)
          when 'tag', 'untag'
            chunk = nil
            next unless @parent_status.account.id == @account.id || @account.user.admin?
            tags = cmd[2..-1].map {|t| t.gsub(':', '.')}
            if cmd[1].downcase == 'tag'
              add_tags(@parent_status, *tags)
            else
              del_tags(@parent_status, *tags)
            end
            Rails.cache.delete("statuses/#{@parent_status.id}")
          when 'emoji'
            @parent_status.emojis.each do |theirs|
              ours = CustomEmoji.find_or_initialize_by(shortcode: theirs.shortcode, domain: nil)
              if ours.id.nil?
                ours.image = theirs.image
                ours.save
                user_friendly_action_log(@account, :create, ours)
              end
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
          end
        when 'media'
          chunk = nil

          media_idx = cmd[1]
          media_cmd = cmd[2]
          media_args = cmd[3..-1]

          next unless media_cmd.present? && media_idx.present? && media_idx.scan(/\D/).empty?
          media_idx = media_idx.to_i
          next if status.media_attachments[media_idx-1].nil?

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
          chunk = chunk.sub('bangtag:', '').gsub(':', ":\u200c")
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
            '\T' => '    '
          }
          sep = charmap[cmd[1]]
          chunk = cmd[2..-1].join(sep.nil? ? cmd[1] : sep)
        when 'hide'
          chunk = nil
          next if cmd[1].nil?
          case cmd[1].downcase
          when 'end', 'stop', 'endall', 'stopall'
            @vore_stack.reject! {|v| v == '_'}
            @compontent_stack.reject! {|c| c == :hide}
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
              @chunks << (["\n# <code>#!</code><code>i:am:list</code>:\n<hr />\n"] + names).join("\n") + "\n"
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
              name = who.downcase.gsub(/\s+/, '').strip
              description = cmd[1..-1].join(':').strip
              if description.blank?
                if @vars["_they:are:#{name}"].nil?
                  @vars["_they:are:#{name}"] = who.strip
                end
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
          @chunks.insert(0, "[center]`#!draft!#`[/center]\n") unless @chunks.present? && @chunks.first.include?('#!draft')
          @status.visibility = :direct
          @status.local_only = true
          @status.content_type = 'text/x-bbcode+markdown'
          @vore_stack.push('_draft')
          @component_stack.push(:var)
          add_tags(status, 'self.draft')
        when 'format', 'type'
          chunk = nil
          next if cmd[1].nil?
          content_types = {
            't'           => 'text/plain',
            'txt'         => 'text/plain',
            'text'        => 'text/plain',
            'plain'       => 'text/plain',
            'plaintext'   => 'text/plain',

            'c'           => 'text/console',
            'console'     => 'text/console',
            'terminal'    => 'text/console',
            'monospace'   => 'text/console',

            'm'           => 'text/markdown',
            'md'          => 'text/markdown',
            'markdown'    => 'text/markdown',

            'b'           => 'text/x-bbcode',
            'bbc'         => 'text/x-bbcode',
            'bbcode'      => 'text/x-bbcode',

            'd'           => 'text/x-bbcode+markdown',
            'bm'          => 'text/x-bbcode+markdown',
            'bbm'         => 'text/x-bbcode+markdown',
            'bbdown'      => 'text/x-bbcode+markdown',

            'h'           => 'text/html',
            'htm'         => 'text/html',
            'html'        => 'text/html',
          }
          v = cmd[1].downcase
          status.content_type = content_types[c] unless content_types[c].nil?
        when 'visibility', 'v'
          chunk = nil
          next if cmd[1].nil?
          visibilities = {
            'direct'      => :direct,
            'dm'          => :direct,
            'whisper'     => :direct,
            'd'           => :direct,

            'private'     => :private,
            'packmate'    => :private,
            'group'       => :private,
            'f'           => :private,
            'g'           => :private,

            'unlisted'    => :unlisted,
            'u'           => :unlisted,

            'local'       => :local,
            'monsterpit'  => :local,
            'community'   => :local,
            'c'           => :local,
            'l'           => :local,
            'm'           => :local,

            'public'      => :public,
            'world'       => :public,
            'p'           => :public,
          }
          allowed_visibility_changes = {
            'unlisted'    => [:local],
            'local'       => [:unlisted],
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
            ActivityPub::DistributionWorker.perform_async(@parent_status) unless @parent_status.local_only?
          else
            v = cmd[1].downcase
            status.visibility = visibilities[v] unless visibilities[v].nil?
            case cmd[2].downcase
            when 'federate', 'f', 'public', 'p', 'world'
              status.local_only = false
            when 'nofederate', 'nf', 'localonly', 'lo', 'local', 'l', 'monsterpit', 'm', 'community', 'c'
              status.local_only = true
            end
          end
        when 'live', 'lifespan', 'l', 'delete_in'
          chunk = nil
          next if cmd[1].nil?
          case cmd[1].downcase
          when 'parent', 'thread', 'all'
            s = cmd[1].downcase.to_sym
            s = @parent_status if s == :parent
            next unless s == :all ||  @parent_status.present?
            next unless s == :thread || s == :all || @parent_status.account_id == @account.id
            i = cmd[2].to_i
            unit = cmd[3].present? ? cmd[3].downcase : 'minutes'
          else
            s = @status
            i = cmd[1].to_i
            unit = cmd[2].present? ? cmd[2].downcase : 'minutes'
          end
          delete_after = case unit
                         when 'min', 'mins', 'minute', 'minutes'
                           i.minutes
                         when 'h', 'hr', 'hrs', 'hour', 'hours'
                           i.hours
                         when 'd', 'dy', 'dys', 'day', 'days'
                           i.days
                         when 'w', 'wk', 'wks', 'week', 'weeks'
                           i.weeks
                         when 'm', 'mn', 'mns', 'month', 'months'
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
            ']', "\\",
          ]

          chunk = rand(6..33).times.collect do
            keyboard[(keyboard.size * (rand ** 3)).floor].split('').sample
          end
          chunk = chunk.join
        when 'admin'
          chunk = nil
          next unless @account.user.admin?
          next if cmd[1].nil?
          @status.visibility = :local
          @status.local_only = true
          add_tags(@status, 'monsterpit.admin.log')
          @status.content_type = 'text/markdown'
          @chunks << "\n# <code>#!</code><code>admin:#{cmd[1].downcase}</code>:\n<hr />\n"
          case cmd[1].downcase
          when 'silence', 'unsilence', 'suspend', 'unsuspend', 'force_unlisted', 'allow_public', 'force_sensitive', 'allow_nonsensitive', 'reset', 'forgive'
            @tf_cmds.push(cmd)
            @component_stack.push(:tf)
          when 'exec', 'eval'
            unless @account.username.in?((ENV['ALLOW_ADMIN_EVAL_FROM'] || '').split)
              @chunks << "<em>Unauthorized.</em>"
              next
            end
            unless cmd[2].present? && cmd[2].downcase == 'last'
              @vars.delete("_admin:eval")
              @vore_stack.push("_admin:eval")
              @component_stack.push(:var)
            end
            @post_cmds.push(['admin', 'eval'])
          when 'announce'
            @vars.delete("_admin:announce")
            @vore_stack.push("_admin:announce")
            @component_stack.push(:var)
            c = ['admin', 'announce']
            c << 'local' if cmd[2].present? && cmd[2].downcase == 'local'
            @post_cmds.push(c)
          when 'unannounce'
            @tf_cmds.push(cmd)
            @component_stack.push(:tf)
          end
        end
      end

      chunk.gsub!("#\uf666!", '#!') unless chunk.blank? || chunk.frozen?

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
            next unless @account.user.admin?
            next if tf_cmd[1].nil? || chunk.start_with?('`admin:')
            output = []
            action = tf_cmd[1].downcase
            case action
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
              chunk.split.each do |c|
                if c.start_with?('@')
                  account_parts = c.split('@')[1..2]
                  successful = account_policy(account_parts[0], account_parts[1], action)
                else
                  successful = domain_policy(c, action)
                end
                if successful
                  output << "\u2705 <code>#{c}</code>"
                else
                  output << "\u274c <code>#{c}</code>"
                end
              end
              output = ['<em>No action.</em>'] if output.blank?
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

    @vars.transform_values! {|v| v.rstrip if v.is_a?(String)}

    postprocess_before_save

    account.user.save

    text = @chunks.join
    text.gsub!(/\n\n+/, "\n") if @crunch_newlines

    if text.blank?
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
          status.media_attachments[media_idx-1].description = @vars["_media:#{media_idx}:desc"]
          status.media_attachments[media_idx-1].save
          @vars.delete("_media:#{media_idx}:desc")
        end
      when 'admin'
        next unless @account.user.admin?
        next if post_cmd[1].nil?
        case post_cmd[1]
        when 'eval'
          @crunch_newlines = true
          @vars["_admin:eval"].strip!
          @chunks << "\n<strong>Input:</strong>"
          @chunks << "<pre><code>"
          @chunks << html_entities.encode(@vars["_admin:eval"]).gsub("\n", '<br/>')
          @chunks << "</code></pre>"
          begin
            result = eval(@vars["_admin:eval"])
          rescue Exception => e
            result = "\u274c #{e.message}"
          end
          @chunks << "<strong>Output:</strong>"
          @chunks << "<pre><code>"
          @chunks << html_entities.encode(result).gsub("\n", '<br/>')
          @chunks << "</code></pre>"
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

          name = @account.user.vars['_they:are']
          if name.present?
            footer = "#{@account.user.vars["_they:are:#{name}"]} from @#{@account.username}"
          else
            footer = "@#{@account.username}"
          end

          s = PostStatusService.new.call(
            announcer,
            visibility: :local,
            text: @vars['_admin:announce'],
            footer: footer,
            local_only: post_cmd[2] == 'local'
          )

          DistributionWorker.perform_async(s.id)
          ActivityPub::DistributionWorker.perform_async(s) unless s.local_only?

          @chunks << 'Announce successful.'
        end
      end
    end
  end

  def postprocess_after_save
    @post_cmds.each do |post_cmd|
      case post_cmd[0]
      when 'mention'
        mention = @account.mentions.where(status: status).first_or_create(status: status)
      end
    end
  end

  def add_tags(to_status, *tags)
    valid_name = /^[[:word:]:._\-]*[[:alpha:]:._·\-][[:word:]:._\-]*$/
    tags = tags.select {|t| t.present? && valid_name.match?(t)}.uniq
    ProcessHashtagsService.new.call(to_status, tags)
    to_status.save
  end

  def del_tags(from_status, *tags)
    valid_name = /^[[:word:]:._\-]*[[:alpha:]:._·\-][[:word:]:._\-]*$/
    tags = tags.select {|t| t.present? && valid_name.match?(t)}.uniq
    tags.map { |str| str.mb_chars.downcase }.uniq(&:to_s).each do |name|
      name.gsub!(/[:.]+/, '.')
      next if name.blank? || name == '.'
      if name.ends_with?('.')
        filtered_tags = from_status.tags.select { |t| t.name == name || t.name.starts_with?(name) }
      else
        filtered_tags = from_status.tags.select { |t| t.name == name }
      end
      from_status.tags.destroy(filtered_tags)
    end
    from_status.save
  end

  def html_entities
    @html_entities ||= HTMLEntities.new
  end
end
