require 'sixarm_ruby_unaccent'

module SearchHelper
	def expand_search_query(query)
    query.downcase.unaccent.gsub(/"(.*)"/, '\\y\1\\y')
  end
end
