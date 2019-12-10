require 'sixarm_ruby_unaccent'

module SearchHelper
	def expand_search_query(query)
    return '' if query.blank?
    if query.include?(':')
      query_parts = query.split(':', 2)
      if query_parts[0].in?(%w(tags subj text desc))
        query = "^#{query_parts[0]} .*#{query_parts[1]}"
      end
    end
    query.downcase.unaccent.gsub(/"(.*)"/, '\\y\1\\y')
  end
end
