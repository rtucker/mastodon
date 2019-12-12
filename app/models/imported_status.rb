# == Schema Information
#
# Table name: imported_statuses
#
#  id        :bigint(8)        not null, primary key
#  status_id :bigint(8)
#  origin    :string
#

class ImportedStatus < ApplicationRecord
  belongs_to :status, inverse_of: :imported_status
  validates_uniqueness_of :status_id
end
