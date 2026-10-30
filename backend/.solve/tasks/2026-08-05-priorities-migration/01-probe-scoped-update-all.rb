# bin/rails runner .solve/tasks/2026-08-05-priorities-migration/01-probe-scoped-update-all.rb
id = Subscription.unscoped.pick(:id)
puts "Current.organization: #{Current.organization.inspect}"
puts "read  (migration used this): #{Subscription.unscoped.where(id: id).to_sql}"
puts "write (migration used this): #{Subscription.where(id: id).to_sql}"

ActiveRecord::Base.transaction do
  puts "rows updated, scoped:   #{Subscription.where(id: id).update_all(role: 'owner')}"
  puts "rows updated, unscoped: #{Subscription.unscoped.where(id: id).update_all(role: 'owner')}"
  raise(ActiveRecord::Rollback)
end
