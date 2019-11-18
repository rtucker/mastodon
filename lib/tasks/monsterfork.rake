# frozen_string_literal: true

def index_statuses(statuses_query)
  include TextHelper

  i = 0
  total = statuses_query.count

  statuses_query.find_in_batches do |statuses|
    ActiveRecord::Base.logger.info("Indexing status #{1+i} of #{total}.")
    ActiveRecord::Base.logger.silence do
      i += statuses.count
      statuses.each do |s|
        begin
          next if s.destroyed?
          s.update_column(:normalized_text, normalize_status(s))
        rescue ActiveRecord::RecordNotFound
          true
        end
      end
    end
  end
end

namespace :monsterfork do
  desc 'Index statuses for search that have not been indexed yet.'
  task index_statuses: :environment do
    index_statuses(Status.where(normalized_text: ''))
  end

  desc 'Reindex all statuses for search.'
  task reindex_statuses: :environment do
    index_statuses(Status)
  end

  desc 'Reindex statuses containing media with descriptions for search.'
  task reindex_media_descs: :environment do
    index_statuses(Status.left_outer_joins(:media_attachments).where('media_attachments.description IS NOT NULL'))
  end
end
