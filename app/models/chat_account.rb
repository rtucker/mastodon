# == Schema Information
#
# Table name: chat_accounts
#
#  id         :bigint(8)        not null, primary key
#  account_id :bigint(8)        not null
#  tag_id     :bigint(8)        not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ChatAccount < ApplicationRecord
  belongs_to :account, inverse_of: :chat_accounts
  belongs_to :tag, inverse_of: :chat_accounts

  validates :account_id, uniqueness: { scope: :tag_id }
end
