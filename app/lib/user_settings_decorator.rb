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
    user.settings['gently_kobolds']      = gently_kobolds_preference if change?('setting_gently_kobolds')
    user.settings['user_is_kobold']      = user_is_kobold_preference if change?('setting_user_is_kobold')

    user.settings['hide_captions']       = hide_captions_preference if change?('setting_hide_captions')
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

  def remove_filtered_preference
    boolean_cast_setting 'setting_remove_filtered'
  end

  def gently_kobolds_preference
    boolean_cast_setting 'setting_gently_kobolds'
  end

  def user_is_kobold_preference
    boolean_cast_setting 'setting_user_is_kobold'
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

  def default_language_preference
    settings['setting_default_language']
  end

  def aggregate_reblogs_preference
    boolean_cast_setting 'setting_aggregate_reblogs'
  end

  def default_content_type_preference
    settings['setting_default_content_type']
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
