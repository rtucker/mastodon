# == Schema Information
#
# Table name: normalized_statuses
#
#  id        :bigint(8)        not null, primary key
#  status_id :bigint(8)
#  text      :text
#

class NormalizedStatus < ApplicationRecord
  belongs_to :status, inverse_of: :normalized_status
end
