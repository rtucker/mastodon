# frozen_string_literal: true

class Scheduler::WerewolfScheduler
  include Sidekiq::Worker
  include Redisable

  STATUS = ENV.fetch('WEREWOLF_STATUS', 'Werewolves successful.')
  FOOTER = ENV.fetch('WEREWOLF_FOOTER', ':werewolf: werewolf-status')

  sidekiq_options unique: :until_executed

  def perform
    return if redis.exists('werewolf-status')
    return unless Setting.werewolf_status

    moon_fraction = SunCalc.moon_illumination(Time.now.utc)[:fraction]

    return unless moon_fraction >= 0.998

    redis.setex('werewolf-status', 1.day, 1)

    announcer = find_announcer_acct
    return if announcer.nil?

    s = PostStatusService.new.call(
      announcer,
      visibility: :public,
      text: STATUS,
      footer: FOOTER,
      content_type: 'text/console',
    )

    DistributionWorker.perform_async(s.id)
    ActivityPub::DistributionWorker.perform_async(s)
  end

  private

  def find_announcer_acct
    announcer = ENV['ANNOUNCEMENTS_USER'].to_i
    return if announcer == 0
    Account.find_by(id: announcer)
  end
end
