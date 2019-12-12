# == Schema Information
#
# Table name: sharekeys
#
#  id        :bigint(8)        not null, primary key
#  status_id :bigint(8)
#  key       :string
#

class Sharekey < ApplicationRecord
  belongs_to :status, inverse_of: :sharekey
  validates_uniqueness_of :status_id
end
