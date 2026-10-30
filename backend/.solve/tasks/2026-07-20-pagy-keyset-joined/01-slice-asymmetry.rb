record = Notification.new

puts "slice(:id)         => #{record.slice(:id).inspect}"

begin
  record.slice(:identifier)
rescue => e
  puts "slice(:identifier) => #{e.class}: #{e.message}"
end
