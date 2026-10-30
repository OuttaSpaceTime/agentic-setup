d = Date.new(2026, 1, 1)
puts "Date#iso8601 arity: #{Date.instance_method(:iso8601).arity}"
begin
  puts "Date#iso8601(6) => #{d.iso8601(6)}"
rescue StandardError => e
  puts "Date#iso8601(6) RAISES: #{e.class}: #{e.message}"
end
c = Component.unscoped.where.not(eol_date: nil).first
if c
  v = c.read_external('eol_date')
  puts "read_external('eol_date') class: #{v.class}, value: #{v.inspect}"
  puts "responds to iso8601? #{v.respond_to?(:iso8601)}"
end
