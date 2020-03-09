# frozen_string_literal: true

class Api::V1::WerewolfController < Api::BaseController
  respond_to :json
  skip_before_action :set_cache_headers
  skip_before_action :require_authenticated_user!

  def index
    render json: werewolf_info
  end

  private

  def werewolf_info
    Rails.cache.fetch("werewolf:info", expires_in: 6.hours) do
      this_fraction = moon_fraction(Time.now.utc)
      {
        werewolf: this_fraction > 0.99,
        lastwolf: last_full_moon.strftime('%F'),
        nextwolf: next_full_moon.strftime('%F'),
        fullness: "#{(this_fraction * 100).round}%",
      }
    end
  end

  def last_full_moon
    now     = Time.now.utc.beginning_of_day
    offset  = 0
    growing = false
    moon    = moon_fraction(now)
    last    = 0

    until growing && moon < last
      last = moon
      offset += 1
      moon = moon_fraction(now - offset.hours)
      growing = true unless growing || moon < last
    end

    offset -= 1
    now - offset.hours
  end

  def next_full_moon
    now     = Time.now.utc.beginning_of_day
    offset  = 0
    growing = false
    moon    = moon_fraction(now)
    last    = 0

    until growing && moon < last
      last = moon
      offset += 1
      moon = moon_fraction(now + offset.hours)
      growing = true unless growing || moon < last
    end

    offset -= 1
    now + offset.hours
  end

  def moon_fraction(time)
    SunCalc.moon_illumination(time)[:fraction]
  end
end
