# bin/rails runner .solve/tasks/2026-10-21-component-pull-inactive-replacement/current.rb
# Checks: the real ComponentPullJob, fed an Aweseno payload "listed component inactive, replaced_by a component deactivated WITHOUT replacement"
# Look at: replacement active=false with empty replaced_by, mapped replaced_by_component_id is the replacement verbatim, then the prod error
ActiveRecord::Base.transaction(joinable: false) do
  listed_component, inactive_replacement = Current.without_organization_and_membership_scopes do
    [
      Component.active.joins(:monitoring_lists).first,
      Component.including_tlp_amber_strict.find(ActiveRecord::FixtureSet.identify(:unactive_component_without_replacement))
    ]
  end
  puts("listed_component=#{listed_component.id} active=#{listed_component.active}")
  puts("inactive_replacement=#{inactive_replacement.id} active=#{inactive_replacement.active} replaced_by=#{inactive_replacement.replaced_by_component_id.inspect}")

  aweseno_payload = {
    'active' => false,
    'monitored_since' => listed_component.created_at.iso8601,
    'component_name' => { 'name' => listed_component.name },
    'vendor' => listed_component.vendor,
    'version' => listed_component.version_info,
    'deletion_details' => {
      'deleted_at' => Time.current.iso8601,
      'reason' => 'replaced',
      'replaced_by_component' => inactive_replacement.id
    }
  }
  Aweseno::Api::Component.define_singleton_method(:show) { |_component| aweseno_payload }
  puts(
    "mapped: #{ComponentPullJob.new.component_json_to_attributes(aweseno_payload).slice(
      :active,
      :replaced_by_component_id
    )}"
  )

  state = lambda {
    listed_component.reload.attributes.slice(
      'active',
      'replaced_by_component_id',
      'last_successful_sync_at',
      'sync_failed_at'
    )
  }
  puts("before job: #{state.call}")
  begin
    ComponentPullJob.perform_now(listed_component)
  rescue StandardError => e
    puts("raised #{e.class}: #{e.message.lines.first}")
    if e.is_a?(ActiveRecord::RecordInvalid)
      puts("  invalid record: #{e.record.class} #{e.record.attributes.slice('component_id', 'monitoring_list_id')}")
      puts("  errors.details: #{e.record.errors.details}")
    end
  end
  puts("after job:  #{state.call}")
  raise(ActiveRecord::Rollback)
end
