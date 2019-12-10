require 'sixarm_ruby_unaccent'

module SearchHelper
	def expand_search_query(query)
    return '' if query.blank?
    query = query.strip.downcase.unaccent

    if query.include?(':')
      query_parts = query.split(':', 2)
      if query_parts[0] == 'tags'
        query = "^tags .*(#{query_parts[1].split.join('|')})"
      elsif query_parts[0].in?(%w(subj text desc))
        query = "^#{query_parts[0]} .*#{query_parts[1]}"
      end
    end

    query.gsub(/"(.*)"/, '\\y\1\\y')
  end
end
