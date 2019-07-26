module LogHelper
  LOG_SCOPE_MODERATION = ENV.fetch('LOG_SCOPE_MODERATION', 'moderation')

  def user_friendly_action_log(source, action, target)
    source = source.username if source.is_a?(Account)

    case action
    when :create
      if target.is_a? DomainBlock
        LogWorker.perform_async("\xf0\x9f\x9a\xab <#{source}> applied a #{target.severity}#{target.force_sensitive? ? " and force sensitive media" : ''}#{target.reject_media? ? " and reject media" : ''} policy on https://#{target.domain}\u200b.", LOG_SCOPE_MODERATION)
      elsif target.is_a? EmailDomainBlock
        LogWorker.perform_async("\u26d4 <#{source}> added a registration block on email domain '#{target.domain}'.", LOG_SCOPE_MODERATION)
      elsif target.is_a? CustomEmoji
        LogWorker.perform_async("\xf0\x9f\x98\xba <#{source}> added the '#{target.shortcode}' emoji. :#{target.shortcode}:", LOG_SCOPE_MODERATION)
      elsif target.is_a? AccountWarning
        LogWorker.perform_async("\xe2\x9a\xa0\xef\xb8\x8f <#{source}> sent someone an admin notice.", LOG_SCOPE_MODERATION)
      end
    when :destroy
      if target.is_a? DomainBlock
        LogWorker.perform_async("\xf0\x9f\x86\x97 <#{source}> reset the policy on https://#{target.domain}\u200b.", LOG_SCOPE_MODERATION)
      elsif target.is_a? EmailDomainBlock
        LogWorker.perform_async("\xf0\x9f\x86\x97 <#{source}> removed the registration block on email domain '#{target.domain}'.", LOG_SCOPE_MODERATION)
      elsif target.is_a? CustomEmoji
        LogWorker.perform_async("\xf0\x9f\x97\x91\xef\xb8\x8f <#{source}> removed the '#{target.shortcode}' emoji.", LOG_SCOPE_MODERATION)
      elsif target.is_a? Status
        LogWorker.perform_async("\xf0\x9f\x97\x91\xef\xb8\x8f <#{source}> removed post #{TagManager.instance.url_for(target, LOG_SCOPE_MODERATION)}\u200b.")
      end

    when :update
      if target.is_a? Status
        LogWorker.perform_async("\xf0\x9f\x91\x81\xef\xb8\x8f <#{source}> changed visibility flags of post #{TagManager.instance.url_for(target, LOG_SCOPE_MODERATION)}\u200b.")
      elsif target.is_a? CustomEmoji
        LogWorker.perform_async("\xf0\x9f\x94\x81 <#{source}> replaced the '#{target.shortcode}' emoji. :#{target.shortcode}:", LOG_SCOPE_MODERATION)
      end

    when :enable
      if target.is_a? User
        LogWorker.perform_async("\xf0\x9f\x92\xa7 <#{source}> unfroze the account of <#{target.username}>.", LOG_SCOPE_MODERATION)
      elsif target.is_a? CustomEmoji
        LogWorker.perform_async("\xf0\x9f\x86\x97 <#{source}> enabled the '#{target.shortcode}' emoji. :#{target.shortcode}:", LOG_SCOPE_MODERATION)
      end
    when :disable
      if target.is_a? User
        LogWorker.perform_async("\xe2\x9d\x84\xef\xb8\x8f <#{source}> froze the account of <#{target.username}>.", LOG_SCOPE_MODERATION)
      elsif target.is_a? CustomEmoji
        LogWorker.perform_async("\u26d4 <#{source}> disabled the '#{target.shortcode}' emoji.", LOG_SCOPE_MODERATION)
      end

    when :force_sensitive
      LogWorker.perform_async("\xf0\x9f\x94\x9e <#{source}> forced the media of <#{target.acct}> to be marked sensitive.", LOG_SCOPE_MODERATION)
    when :force_unlisted
      LogWorker.perform_async("\xf0\x9f\x94\x89 <#{source}> forced the posts of <#{target.acct}> to be unlisted.", LOG_SCOPE_MODERATION)
    when :silence
      LogWorker.perform_async("\xf0\x9f\x94\x87 <#{source}> silenced <#{target.acct}>'.", LOG_SCOPE_MODERATION)
    when :suspend
      LogWorker.perform_async("\u26d4 <#{source}> suspended <#{target.acct}>.", LOG_SCOPE_MODERATION)

    when :allow_nonsensitive
      LogWorker.perform_async("\xf0\x9f\x86\x97 <#{source}> allowed <#{target.acct}> to post media without a sensitive flag.", LOG_SCOPE_MODERATION)
    when :allow_public
      LogWorker.perform_async("\xf0\x9f\x86\x8a <#{source}> allowed <#{target.acct}> to post with public visibility.", LOG_SCOPE_MODERATION)
    when :unsilence
      LogWorker.perform_async("\xf0\x9f\x94\x8a <#{source}> unsilenced <#{target.acct}>.", LOG_SCOPE_MODERATION)
    when :unsuspend
      LogWorker.perform_async("\xf0\x9f\x86\x97 <#{source}> unsuspended <#{target.acct}>.", LOG_SCOPE_MODERATION)

    when :remove_avatar
      LogWorker.perform_async("\xf0\x9f\x97\x91\xef\xb8\x8f <#{source}> removed the avatar of <#{target.acct}>.", LOG_SCOPE_MODERATION)
    when :remove_header
      LogWorker.perform_async("\xf0\x9f\x97\x91\xef\xb8\x8f <#{source}> removed the profile header of <#{target.acct}>.", LOG_SCOPE_MODERATION)

    when :resolve
      LogWorker.perform_async("\u2705 <#{source}> resolved report ##{target.id}.", LOG_SCOPE_MODERATION)
    when :reopen
      LogWorker.perform_async("\u2757 <#{source}> reopened report ##{target.id}.", LOG_SCOPE_MODERATION)
    when :assigned_to_self
      LogWorker.perform_async("\xf0\x9f\x91\x80 <#{source}> is resolving report ##{target.id}.", LOG_SCOPE_MODERATION)
    when :unassigned
      LogWorker.perform_async("\u274c <#{source}> is no longer assigned to report ##{target.id}.", LOG_SCOPE_MODERATION)

    when :promote
      LogWorker.perform_async("\xf0\x9f\x94\xba <#{source}> upgraded a local account from #{target.role}.", LOG_SCOPE_MODERATION)
    when :demote
      LogWorker.perform_async("\xf0\x9f\x94\xbb <#{source}> downgraded a local account from #{target.role}.", LOG_SCOPE_MODERATION)

    when :confirm
      LogWorker.perform_async("\u2705 <#{source}> manually confirmed a local account.", LOG_SCOPE_MODERATION)
    when :reset_password
      LogWorker.perform_async("\xf0\x9f\x94\x81 <#{source}> manually reset a local account's password.", LOG_SCOPE_MODERATION)
    when :disable_2fa
      LogWorker.perform_async("\xf0\x9f\x94\x81 <#{source}> manually reset a local account's 2-factor auth.", LOG_SCOPE_MODERATION)
    when :change_email
      LogWorker.perform_async("\xf0\x9f\x93\x9d <#{source}> manually changed a local account's email address.", LOG_SCOPE_MODERATION)

    when :memorialize
      LogWorker.perform_async("\xf0\x9f\x8f\x85 <#{source}> memorialized an account.", LOG_SCOPE_MODERATION)
    end
  end
end
