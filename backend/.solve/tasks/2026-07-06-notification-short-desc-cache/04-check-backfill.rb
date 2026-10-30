remaining = Inbox::Item.unscoped
  .where(itemable_type: 'MonitoringList::NotificationItem', short_description_index: nil)
  .count

puts "remaining null short_description_index: #{remaining}"

sample = Inbox::Item.unscoped
  .where(itemable_type: 'MonitoringList::NotificationItem')
  .where.not(short_description_index: nil)
  .first

puts "sample: #{sample&.short_description_index.inspect}"
