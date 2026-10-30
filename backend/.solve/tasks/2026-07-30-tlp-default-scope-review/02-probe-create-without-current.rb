# bin/rails runner .solve/tasks/2026-07-30-tlp-default-scope-review/02-probe-create-without-current.rb
Current.set_to_empty do
  ml = MonitoringList.new(name: 'probe')
  puts "organization_id: #{ml.organization_id.inspect}"
  puts "valid?: #{ml.valid?.inspect}"
  puts "errors: #{ml.errors.full_messages.inspect}"
end
