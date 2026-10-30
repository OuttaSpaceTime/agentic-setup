TARGET_ITEMS = 150

org = Current.without_organization_and_membership_scopes { Organization.find_by!(name: 'Organization A') }
superuser = User.find_by!(email: 'superuser@example.com')
membership = Current.without_organization_and_membership_scopes do
  Membership.find_by!(organization: org, role: 'admin', user: superuser)
end

ActiveRecord::Base.transaction do
  Current.set(organization: org) do
    monitoring_list = MonitoringList.order(:name).first!
    TARGET_ITEMS.times do |i|
      event = Inbox::Event::MonitoringList::Notification.find_or_create_by!(organization: org, ml_name_snapshot: "Seed Inbox #{i + 1}") { |e| e.changed_monitoring_list = monitoring_list }
      item = Inbox::Item::MonitoringList::Notification.find_or_create_by!(
        event: event,
        membership: membership,
        organization: org
      )
      Inbox::Item.find_or_create_by!(itemable: item, membership: membership) { |record| record.organization = org }
    end
    puts("inbox items for #{superuser.email}/#{org.name}: #{membership.inbox_items.count} (page size #{Inbox::Item.default_page_size})")
    raise(ActiveRecord::Rollback) if ENV['DRY_RUN']
  end
end
