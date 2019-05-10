class UpdateDomainBlockSeverityEnum < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    DomainBlock.where(severity: :force_unlisted).each do |block|
      block.severity = :suspend
      block.save
    end

    DomainBlock.where(severity: :noop).each do |block|
      block.severity = :silence
      block.save
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
