# frozen_string_literal: true

class UnblockService < BaseService
  def call(account, target_account)
    return unless account.blocking?(target_account)

    unblock = account.unblock!(target_account)
    create_notification(unblock) unless target_account.local?
    unblock
  end

  private

  def create_notification(unblock)
    ActivityPub::DeliveryWorker.perform_async(build_json(unblock), unblock.account_id, unblock.target_account.inbox_url)
  end

  def build_json(unblock)
    ActiveModelSerializers::SerializableResource.new(
      unblock,
      serializer: ActivityPub::UndoBlockSerializer,
      adapter: ActivityPub::Adapter
    ).to_json
  end
end
