class ValidateSetDefaultUnhiddenOnStatuses < ActiveRecord::Migration[5.2]
  def change
    safety_assured do
      execute 'ALTER TABLE "statuses" VALIDATE CONSTRAINT "statuses_hidden_null"'
    end
  end
end
