[ComponentRequest, Subscription].each do |model|
  allowed = model.orderable_columns.include?('membership')
  puts "#{model.name}: sort=membership allowed? #{allowed}"
end
