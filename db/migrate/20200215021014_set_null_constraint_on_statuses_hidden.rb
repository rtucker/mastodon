class SetNullConstraintOnStatusesHidden < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      execute 'ALTER TABLE "statuses" ADD CONSTRAINT "statuses_hidden_null" CHECK ("hidden" IS NOT NULL) NOT VALID'
    end
  end
end
