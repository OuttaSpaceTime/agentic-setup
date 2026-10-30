# bin/rails runner .solve/tasks/2026-08-05-priorities-migration/02-probe-empty-priorities.rb
all = Subscription.unscoped
puts "subscriptions:       #{all.count}"
puts "priorities = '{}':   #{all.where(priorities: []).count}"
puts "created_at range:    #{all.minimum(:created_at)} .. #{all.maximum(:created_at)}"
