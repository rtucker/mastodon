# == Schema Information
#
# Table name: defederating_statuses
#
#  id               :bigint(8)        not null, primary key
#  status_id        :bigint(8)
#  defederate_after :datetime
#

class DefederatingStatus < ApplicationRecord
  belongs_to :status, inverse_of: :defederating_status

  validate :validate_future_date
  validates :status_id, uniqueness: true

  private

  def validate_future_date
    errors.add(:defederate_after, I18n.t('defederating_statuses.too_soon')) if defederate_after.present? && defederate_after < Time.now.utc + PostStatusService::MIN_DESTRUCT_OFFSET
  end
end
