class ClearFilterCache < ActiveRecord::Migration[5.2]
  include Redisable

  def change
    ['custom_cw', 'filtered_threads', 'filtered_statuses'].each do |ns|
      Rails.logger.info("Clearing keys matching '#{ns}:*' ...")
      Rails.cache.delete_matched("#{ns}:*")
      keys = redis.keys("#{ns}:*")
      redis.del(*keys) unless keys.empty?
    end
  end
end
