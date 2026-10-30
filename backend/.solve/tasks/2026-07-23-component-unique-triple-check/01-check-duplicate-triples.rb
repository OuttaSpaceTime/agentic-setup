conn = ActiveRecord::Base.connection

puts("Total component rows: #{conn.select_value('SELECT count(*) FROM components')}")

dupes = conn.select_all(<<~SQL).to_a
  SELECT cv.name AS vendor, cn.name AS name, c.version_info, count(*) AS n
  FROM components c
  LEFT JOIN component_vendors cv ON cv.id = c.component_vendor_id
  LEFT JOIN component_names   cn ON cn.id = c.component_name_id
  WHERE c.active
  GROUP BY cv.name, cn.name, c.version_info
  HAVING count(*) > 1
  ORDER BY n DESC
SQL

puts("Duplicate triples (would block UNIQUE index): #{dupes.size}")
dupes.first(20).each do |r|
  puts("  #{r['n'].to_s.rjust(4)}x  [#{r['vendor'].inspect}, #{r['name'].inspect}, #{r['version_info'].inspect}]")
end
