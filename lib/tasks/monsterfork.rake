namespace :monsterfork do
  desc '(Re-)Index statuses for search.'
  task index_statuses: :environment do
    include TextHelper

    i = 0
    total = Status.count

    Status.find_in_batches do |statuses|
      ActiveRecord::Base.logger.info("Indexing status #{1+i} of #{total}.")
      ActiveRecord::Base.logger.silence do
        i += statuses.count
        statuses.each do |s|
          s.update_column(:normalized_text, normalize_status(s, cache: false))
        end
      end
    end
  end
end
