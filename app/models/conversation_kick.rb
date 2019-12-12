# == Schema Information
#
# Table name: conversation_kicks
#
#  id              :bigint(8)        not null, primary key
#  account_id      :bigint(8)        not null
#  conversation_id :bigint(8)        not null
#

class ConversationKick < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
end
