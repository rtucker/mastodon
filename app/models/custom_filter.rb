# frozen_string_literal: true
# == Schema Information
#
# Table name: custom_filters
#
#  id         :bigint(8)        not null, primary key
#  account_id :bigint(8)
#  expires_at :datetime
#  phrase     :text             default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class CustomFilter < ApplicationRecord
  include Expireable
  include Redisable

  belongs_to :account

  validates :phrase, presence: true

  after_commit :remove_cache

  private

  def remove_cache
    Rails.cache.delete("filters:#{account_id}")
    redis.del("custom_cw:#{account_id}")
    redis.del("filtered_threads:#{account_id}")
    redis.del("filtered_statuses:#{account_id}")
    Redis.current.publish("timeline:#{account_id}", Oj.dump(event: :filters_changed))
  end
end
