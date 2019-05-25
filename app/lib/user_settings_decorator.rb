# frozen_string_literal: true

class UserSettingsDecorator
  attr_reader :user, :settings

  def initialize(user)
    @user = user
  end

  def update(settings)
    @settings = settings
    process_update
  end

  private

  def process_update
    user.settings['default_local']       = default_local_preference if change?('setting_default_local')
    user.settings['always_local']        = always_local_preference if change?('setting_always_local')
    user.settings['rawr_federated']      = rawr_federated_preference if change?('setting_rawr_federated')
    user.settings['hide_stats']          = hide_stats_preference if change?('setting_hide_stats')
    user.settings['larger_menus']        = larger_menus_preference if change?('setting_larger_menus')
    user.settings['larger_buttons']      = larger_buttons_preference if change?('setting_larger_buttons')
    user.settings['larger_drawer']       = larger_drawer_preference if change?('setting_larger_drawer')
    user.settings['remove_filtered']     = remove_filtered_preference if change?('setting_remove_filtered')
    user.settings['hide_replies_muted']  = hide_replies_muted_preference if change?('setting_hide_replies_muted')
    user.settings['hide_replies_blocked']= hide_replies_blocked_preference if change?('setting_hide_replies_blocked')
    user.settings['hide_replies_blocker']= hide_replies_blocker_preference if change?('setting_hide_replies_blocker')
    user.settings['hide_mntions_muted']  = hide_mntions_muted_preference if change?('setting_hide_mntions_muted')
    user.settings['hide_mntions_blocked']= hide_mntions_blocked_preference if change?('setting_hide_mntions_blocked')
    user.settings['hide_mntions_blocker']= hide_mntions_blocker_preference if change?('setting_hide_mntions_blocker')
    user.settings['hide_mntions_packm8'] = hide_mntions_packm8_preference if change?('setting_hide_mntions_packm8')
    user.settings['hide_captions']       = hide_captions_preference if change?('setting_hide_captions')
    user.settings['hide_mascot']         = hide_mascot_preference if change?('setting_hide_mascot')
    user.settings['hide_interactions']   = hide_interactions_preference if change?('setting_hide_interactions')
    user.settings['hide_public_profile'] = hide_public_profile_preference if change?('setting_hide_public_profile')
    user.settings['hide_public_outbox']  = hide_public_outbox_preference if change?('setting_hide_public_outbox')
    user.settings['larger_emoji']        = larger_emoji_preference if change?('setting_larger_emoji')
    user.settings['max_public_history']  = max_public_history_preference if change?('setting_max_public_history')
    user.settings['roar_lifespan']       = roar_lifespan_preference if change?('setting_roar_lifespan')
    user.settings['delayed_roars']       = delayed_roars_preference if change?('setting_delayed_roars')
    user.settings['delayed_for']         = delayed_for_preference if change?('setting_delayed_for')
    user.settings['boost_interval']      = boost_interval_preference if change?('setting_boost_interval')
    user.settings['boost_random']        = boost_random_preference if change?('setting_boost_random')
    user.settings['boost_interval_from'] = boost_interval_from_preference if change?('setting_boost_interval_from')
    user.settings['boost_interval_to']   = boost_interval_to_preference if change?('setting_boost_interval_to')
    user.settings['show_cursor']         = show_cursor_preference if change?('setting_show_cursor')

    user.settings['notification_emails'] = merged_notification_emails if change?('notification_emails')
    user.settings['interactions']        = merged_interactions if change?('interactions')
    user.settings['default_privacy']     = default_privacy_preference if change?('setting_default_privacy')
    user.settings['default_sensitive']   = default_sensitive_preference if change?('setting_default_sensitive')
    user.settings['default_language']    = default_language_preference if change?('setting_default_language')
    user.settings['unfollow_modal']      = unfollow_modal_preference if change?('setting_unfollow_modal')
    user.settings['boost_modal']         = boost_modal_preference if change?('setting_boost_modal')
    user.settings['favourite_modal']     = favourite_modal_preference if change?('setting_favourite_modal')
    user.settings['delete_modal']        = delete_modal_preference if change?('setting_delete_modal')
    user.settings['auto_play_gif']       = auto_play_gif_preference if change?('setting_auto_play_gif')
    user.settings['display_media']       = display_media_preference if change?('setting_display_media')
    user.settings['expand_spoilers']     = expand_spoilers_preference if change?('setting_expand_spoilers')
    user.settings['reduce_motion']       = reduce_motion_preference if change?('setting_reduce_motion')
    user.settings['system_font_ui']      = system_font_ui_preference if change?('setting_system_font_ui')
    user.settings['noindex']             = noindex_preference if change?('setting_noindex')
    user.settings['hide_followers_count']= hide_followers_count_preference if change?('setting_hide_followers_count')
    user.settings['flavour']             = flavour_preference if change?('setting_flavour')
    user.settings['skin']                = skin_preference if change?('setting_skin')
    user.settings['hide_network']        = hide_network_preference if change?('setting_hide_network')
    user.settings['aggregate_reblogs']   = aggregate_reblogs_preference if change?('setting_aggregate_reblogs')
    user.settings['show_application']    = show_application_preference if change?('setting_show_application')
    user.settings['default_content_type']= default_content_type_preference if change?('setting_default_content_type')
    user.settings['theme']               = theme_preference if change?('setting_theme')
    user.settings['advanced_layout']     = advanced_layout_preference if change?('setting_advanced_layout')
  end

  def larger_menus_preference
    boolean_cast_setting 'setting_larger_menus'
  end

  def larger_buttons_preference
    boolean_cast_setting 'setting_larger_buttons'
  end

  def larger_drawer_preference
    boolean_cast_setting 'setting_larger_drawer'
  end

  def larger_emoji_preference
    boolean_cast_setting 'setting_larger_emoji'
  end

  def remove_filtered_preference
    boolean_cast_setting 'setting_remove_filtered'
  end

  def hide_replies_muted_preference
    boolean_cast_setting 'setting_hide_replies_muted'
  end

  def hide_replies_blocked_preference
    boolean_cast_setting 'setting_hide_replies_blocked'
  end

  def hide_replies_blocker_preference
    boolean_cast_setting 'setting_hide_replies_blocker'
  end

  def hide_mntions_muted_preference
    boolean_cast_setting 'setting_hide_mntions_muted'
  end

  def hide_mntions_blocked_preference
    boolean_cast_setting 'setting_hide_mntions_blocked'
  end

  def hide_mntions_blocker_preference
    boolean_cast_setting 'setting_hide_mntions_blocker'
  end

  def hide_mntions_packm8_preference
    boolean_cast_setting 'setting_hide_mntions_packm8'
  end

  def hide_mascot_preference
    boolean_cast_setting 'setting_hide_mascot'
  end

  def hide_interactions_preference
    boolean_cast_setting 'setting_hide_interactions'
  end

  def hide_public_profile_preference
    boolean_cast_setting 'setting_hide_public_profile'
  end

  def hide_public_outbox_preference
    boolean_cast_setting 'setting_hide_public_outbox'
  end

  def max_public_history_preference
    settings['setting_max_public_history']
  end

  def roar_lifespan_preference
    settings['setting_roar_lifespan']
  end

  def delayed_for_preference
    settings['setting_delayed_for']
  end

  def show_cursor_preference
    boolean_cast_setting 'setting_show_cursor'
  end

  def delayed_roars_preference
    boolean_cast_setting 'setting_delayed_roars'
  end

  def boost_interval_preference
    boolean_cast_setting 'setting_boost_interval'
  end

  def boost_random_preference
    boolean_cast_setting 'setting_boost_random'
  end

  def boost_interval_from_preference
    settings['setting_boost_interval_from']
  end

  def boost_interval_to_preference
    settings['setting_boost_interval_to']
  end

  def delayed_for_preference
    settings['setting_delayed_for']
  end

  def merged_notification_emails
    user.settings['notification_emails'].merge coerced_settings('notification_emails').to_h
  end

  def merged_interactions
    user.settings['interactions'].merge coerced_settings('interactions').to_h
  end

  def default_privacy_preference
    settings['setting_default_privacy']
  end

  def default_local_preference
    boolean_cast_setting 'setting_default_local'
  end

  def always_local_preference
    boolean_cast_setting 'setting_always_local'
  end

  def rawr_federated_preference
    boolean_cast_setting 'setting_rawr_federated'
  end

  def hide_stats_preference
    boolean_cast_setting 'setting_hide_stats'
  end

  def hide_captions_preference
    boolean_cast_setting 'setting_hide_captions'
  end

  def default_sensitive_preference
    boolean_cast_setting 'setting_default_sensitive'
  end

  def unfollow_modal_preference
    boolean_cast_setting 'setting_unfollow_modal'
  end

  def boost_modal_preference
    boolean_cast_setting 'setting_boost_modal'
  end

  def favourite_modal_preference
    boolean_cast_setting 'setting_favourite_modal'
  end

  def delete_modal_preference
    boolean_cast_setting 'setting_delete_modal'
  end

  def system_font_ui_preference
    boolean_cast_setting 'setting_system_font_ui'
  end

  def auto_play_gif_preference
    boolean_cast_setting 'setting_auto_play_gif'
  end

  def display_media_preference
    settings['setting_display_media']
  end

  def expand_spoilers_preference
    boolean_cast_setting 'setting_expand_spoilers'
  end

  def reduce_motion_preference
    boolean_cast_setting 'setting_reduce_motion'
  end

  def noindex_preference
    boolean_cast_setting 'setting_noindex'
  end

  def hide_followers_count_preference
    boolean_cast_setting 'setting_hide_followers_count'
  end

  def flavour_preference
    settings['setting_flavour']
  end

  def skin_preference
    settings['setting_skin']
  end

  def hide_network_preference
    boolean_cast_setting 'setting_hide_network'
  end

  def show_application_preference
    boolean_cast_setting 'setting_show_application'
  end

  def theme_preference
    settings['setting_theme']
  end

  def default_language_preference
    settings['setting_default_language']
  end

  def aggregate_reblogs_preference
    boolean_cast_setting 'setting_aggregate_reblogs'
  end

  def default_content_type_preference
    settings['setting_default_content_type']
  end

  def advanced_layout_preference
    boolean_cast_setting 'setting_advanced_layout'
  end

  def boolean_cast_setting(key)
    ActiveModel::Type::Boolean.new.cast(settings[key])
  end

  def coerced_settings(key)
    coerce_values settings.fetch(key, {})
  end

  def coerce_values(params_hash)
    params_hash.transform_values { |x| ActiveModel::Type::Boolean.new.cast(x) }
  end

  def change?(key)
    !settings[key].nil?
  end
end
