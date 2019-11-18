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
end
