# RAILS_ENV=test bin/rails runner .solve/tasks/2026-07-27-mutation-proof/billing_probe.rb
ActiveRecord::Base.transaction do
  org = Organization.find_by!(name: 'Expired Organization with Pending Report')
  puts "org.expired? = #{org.expired?}"

  member = Current.without_organization_and_membership_scopes { Membership.find_by!(organization: org) }
  Current.set(organization: org) { member.update!(role: 'admin', expires_at: nil) }
  puts "admin membership: #{member.user.email} expired?=#{member.expired?}"

  period = Current.set(organization: org) { Billing::ConsumptionPeriod.in_the_past.not_archived.sole }
  puts "period upper = #{period.period.last} (in the past, not archived)"

  ActionMailer::Base.deliveries.clear
  Billing::ArchivedReport.stubs(:new).never rescue nil

  report = Current.set(organization: org) { Billing::ArchivedReport.create!(consumption_period: period) }
  Billing::SendConsumptionReportJob.perform_now(report)
  Billing::ConsumptionReportMail.where(archived_report: report).each do |mail|
    Billing::ConsumptionReportMail::SendJob.perform_now(mail)
  end

  puts "---"
  puts "deliveries to EXPIRED org: #{ActionMailer::Base.deliveries.count}"
  ActionMailer::Base.deliveries.each { |m| puts "  to=#{m.to.inspect} subject=#{m.subject.inspect}" }

  raise(ActiveRecord::Rollback)
end
