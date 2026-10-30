# bin/rails runner .solve/tasks/2026-10-21-component-pull-inactive-replacement/current.rb
# Checks: replacing a listed component with an INACTIVE replacement raises the prod error; an ACTIVE one doesn't
# Look at: "inactive" run prints "Component must not be inactive, Monitoring list is invalid", "active" run prints "ok"
{ 'inactive' => :replaced_component, 'active' => :insecure_component }.each do |label, fixture|
  ActiveRecord::Base.transaction do
    component, replacement = Current.without_organization_and_membership_scopes do
      [
        Component.active.joins(:monitoring_lists).where.not(id: ActiveRecord::FixtureSet.identify(fixture)).first,
        Component.including_tlp_amber_strict.find(ActiveRecord::FixtureSet.identify(fixture))
      ]
    end
    puts("#{label}: component=#{component.id} replacement=#{replacement.id} replacement.active=#{replacement.active}")
    begin
      component.update!(active: false, replaced_by_component_id: replacement.id)
      puts("#{label}: ok")
    rescue ActiveRecord::RecordInvalid => e
      puts("#{label}: #{e.class}: #{e.message}")
    end
    raise(ActiveRecord::Rollback)
  end
end
