scope = Notification.where(id: -1).joins(:cves)

puts "pluck('cves.id') SQL:"
puts "  #{scope.pluck('notifications.id', 'cves.id') && scope.select('notifications.id', 'cves.id').to_sql}"
begin
  scope.pluck('notifications.id', 'cves.id')
  puts "  pluck OK"
rescue => e
  puts "  #{e.class}: #{e.message.lines.first.strip}"
end

puts "\nensure_select appends unqualified .select(:id) onto a cve_id select:"
selected = scope.select('cves.id as cve_id').select(:id)
puts "  SQL: #{selected.to_sql}"
begin
  selected.load
  puts "  loaded OK"
rescue => e
  puts "  #{e.class}: #{e.message.lines.first.strip}"
end
