# bin/rails runner .solve/tasks/2026-08-05-priorities-migration/04-probe-empty-priorities-delivery.rb
join = 'JOIN notifications n ON n.priority = ANY(subscriptions.priorities)'

Current.without_organization_and_membership_scopes do
  sub = Subscription.first
  matches = -> { Subscription.where(id: sub.id).joins(join).count }

  puts "priorities: #{sub.priorities.inspect}"
  puts "notifications matched by the delivery join: #{matches.call}"

  ActiveRecord::Base.transaction do
    Subscription.where(id: sub.id).update_all(priorities: [])
    puts "priorities: #{Subscription.find(sub.id).priorities.inspect}"
    puts "notifications matched by the delivery join: #{matches.call}"
    raise(ActiveRecord::Rollback)
  end
end
