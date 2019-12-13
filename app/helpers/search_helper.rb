require 'sixarm_ruby_unaccent'

module SearchHelper
	def expand_search_query(query)
    return '' if query.blank?
    query = query.downcase.unaccent.gsub(/[^\p{Word} [:punct:]]/, '').gsub(/  +/, ' ').strip
    return '' if query.blank?

    if query.include?(':')
      query_parts = query.split(':', 2)
      if %w(tag tags).include?(query_parts[0])
        query = "^tag (#{query_parts[1].split.join('|')})"
      elsif %w(subj text desc).include?(query_parts[0])
        query = "^#{query_parts[0]} .*#{query_parts[1]}"
      end
    end

    query.gsub(/"(.*)"/, '\\y\1\\y')
  end
end
