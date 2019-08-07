# == Schema Information
#
# Table name: queued_boosts
#
#  id         :bigint(8)        not null, primary key
#  account_id :bigint(8)
#  status_id  :bigint(8)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class QueuedBoost < ApplicationRecord
  belongs_to :account, inverse_of: :queued_boosts
  belongs_to :status, inverse_of: :queued_boosts

  validates :account_id, uniqueness: { scope: :status_id }
end
