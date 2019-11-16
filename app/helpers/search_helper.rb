module SearchHelper

	def expand_search_query(query)
    query.gsub(/"(.*)"/, '\\y\1\\y')
  end
end
