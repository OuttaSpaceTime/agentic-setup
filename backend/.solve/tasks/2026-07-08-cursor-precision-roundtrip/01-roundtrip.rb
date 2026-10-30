t = Time.utc(2026, 1, 1, 12, 0, 0, 77459)
cast = ->(v) { Inbox::Item.type_for_attribute('created_at').cast(v) }

default_json = JSON.parse([t].to_json).first
pre_serialized = t.iso8601(6)

puts "original usec:            #{t.usec}"
puts "to_json (no fix):         #{default_json}  -> cast usec #{cast.(default_json).usec}"
puts "iso8601(6) (pre_serialize): #{pre_serialized}  -> cast usec #{cast.(pre_serialized).usec}"
puts "round-trips exactly:      #{cast.(pre_serialized) == t}"
