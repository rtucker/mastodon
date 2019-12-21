# frozen_string_literal: true

class Settings::PreferencesController < Settings::BaseController
  include Redisable

  layout 'admin'

  before_action :authenticate_user!

  def show; end

  def update
    user_settings.update(user_settings_params.to_h)

    if current_user.update(user_params)
      I18n.locale = current_user.locale
      redirect_to settings_preferences_path, notice: I18n.t('generic.changes_saved_msg')
    else
      render :show
    end
  end

  private

  def user_settings
    UserSettingsDecorator.new(current_user)
  end

  def user_params
    params.require(:user).permit(
      :locale,
      :hide_boosts,
      :only_known,
      :invert_filters,
      chosen_languages: []
    )
  end

  def user_settings_params
    params.require(:user).permit(
      :setting_default_local,
      :setting_always_local,
      :setting_rawr_federated,
      :setting_hide_stats,
      :setting_force_lowercase,
      :setting_hide_captions,
      :setting_larger_menus,
      :setting_larger_buttons,
      :setting_larger_drawer,
      :setting_larger_emoji,
      :setting_filter_mentions,
      :setting_hide_replies_muted,
      :setting_hide_replies_blocked,
      :setting_hide_replies_blocker,
      :setting_hide_mntions_muted,
      :setting_hide_mntions_blocked,
      :setting_hide_mntions_blocker,
      :setting_hide_mntions_packm8,
      :setting_gently_kobolds,
      :setting_user_is_kobold,
      :setting_hide_mascot,
      :setting_hide_interactions,
      :setting_hide_public_profile,
      :setting_hide_public_outbox,
      :setting_max_public_history,
      :setting_roar_lifespan,
      :setting_delayed_roars,
      :setting_delayed_for,
      :setting_boost_interval,
      :setting_boost_random,
      :setting_boost_interval_from,
      :setting_boost_interval_to,
      :setting_show_cursor,

      :setting_default_privacy,
      :setting_default_sensitive,
      :setting_default_language,
      :setting_unfollow_modal,
      :setting_boost_modal,
      :setting_favourite_modal,
      :setting_delete_modal,
      :setting_auto_play_gif,
      :setting_display_media,
      :setting_expand_spoilers,
      :setting_reduce_motion,
      :setting_system_font_ui,
      :setting_noindex,
      :setting_hide_network,
      :setting_hide_followers_count,
      :setting_aggregate_reblogs,
      :setting_show_application,
      :setting_default_content_type,

      :setting_theme,
      :setting_advanced_layout,
      notification_emails: %i(follow follow_request reblog favourite mention digest report pending_account),
      interactions: %i(must_be_follower must_be_following)
    )
  end
end
