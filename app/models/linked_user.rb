# == Schema Information
#
# Table name: linked_users
#
#  id             :bigint(8)        not null, primary key
#  user_id        :bigint(8)
#  target_user_id :bigint(8)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

class LinkedUser < ApplicationRecord
  belongs_to :user, inverse_of: :linked_users
  belongs_to :target_user, class_name: 'User'

  validates :user_id, uniqueness: { scope: :target_user_id }
end
