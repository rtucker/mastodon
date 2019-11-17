namespace :monsterfork do
  desc '(Re-)Index statuses for search.'
  task index_statuses: :environment do
    include TextHelper

    i = 0
    total = Status.count

    Status.find_in_batches do |statuses|
      ActiveRecord::Base.logger.info("Indexing status #{1+i} of #{total}.")
      i += statuses.count
      statuses.each do |s|
        ActiveRecord::Base.logger.silence { s.update_column(:normalized_text, normalize_status(s)) }
      end
    end
  end
end
