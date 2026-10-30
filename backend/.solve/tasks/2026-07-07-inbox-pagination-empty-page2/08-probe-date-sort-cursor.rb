ids = Component.unscoped.limit(3).ids
Component.unscoped.where(id: ids).each_with_index { |c, i| c.update_columns(eol_date: Date.new(2026, 1, 1 + i)) }
scope = Component.unscoped.where(id: ids)
paginator = Component.paginator(page_size: 2)
begin
  page1 = paginator.sort_and_paginate(scope, sort: '-end_of_life_on')
  puts "page1 ids: #{page1.map(&:id).inspect}"
  puts "next link: #{page1.links[:next].inspect}"
rescue StandardError => e
  puts "RAISES: #{e.class}: #{e.message}"
  puts e.backtrace.grep(/json_api_cursor|readable/).first(3)
end
