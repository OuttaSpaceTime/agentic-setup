# bin/rails runner .solve/tasks/2026-08-05-priorities-migration/05-probe-update-all-sql.rb
ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
  next unless payload[:sql].start_with?('UPDATE')

  puts "sql:   #{payload[:sql]}"
  puts "binds: #{payload[:binds].map { |b| [b.name, b.value] }.inspect}"
end

Current.without_organization_and_membership_scopes do
  id = Subscription.pick(:id)
  ActiveRecord::Base.transaction do
    Subscription.where(id: id).update_all(priorities: %w[critical major])
    raise(ActiveRecord::Rollback)
  end
end
