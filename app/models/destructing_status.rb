# == Schema Information
#
# Table name: destructing_statuses
#
#  id           :bigint(8)        not null, primary key
#  status_id    :bigint(8)
#  delete_after :datetime
#

class DestructingStatus < ApplicationRecord
  belongs_to :status, inverse_of: :destructing_status

  validate :validate_future_date
  validates :status_id, uniqueness: true

  private

  def validate_future_date
    errors.add(:delete_after, I18n.t('destructing_statuses.too_soon')) if delete_after.present? && delete_after < Time.now.utc + PostStatusService::MIN_DESTRUCT_OFFSET
  end
end
