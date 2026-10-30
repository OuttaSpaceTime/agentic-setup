# bin/rails runner .solve/tasks/2026-08-12-preload-waste/01-serialize-notification-with-one-field.rb
Current.without_organization_and_membership_scopes do
  notification = Notification.includable.first
  pp NotificationSerializer.new(notification, fields: { notifications: [:title] }).serializable_hash[:data]
  pp loaded: %i[references cves histories visible_vulnerabilities visible_components advisories]
    .select { |assoc| notification.association(assoc).loaded? }
end
