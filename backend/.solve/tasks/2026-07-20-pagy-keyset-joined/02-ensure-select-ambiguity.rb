scope = Notification.where(id: -1).joins(:cves)

puts "keyset for order(:id, cves:{id: :desc}):"
ks = Pagy::Keyset.new(scope.order(:id, cves: { id: :desc }), limit: 1, jsonapi: true)
puts "  @keyset.keys = #{ks.send(:instance_variable_get, :@keyset).keys.inspect}"

puts "\nwith a custom select, ensure_select appends .select(:id):"
selected = scope.select('cves.id as cve_id').select(:id)
puts "  SQL: #{selected.to_sql}"
begin
  selected.load
  puts "  loaded OK"
rescue => e
  puts "  #{e.class}: #{e.message.lines.first.strip}"
end
