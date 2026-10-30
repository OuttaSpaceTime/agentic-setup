# Compare how the MonitoringList index loads the `components` relationship for a 200-list page.
#   V0 current:  includes(:visible_components)                 -> MonitoringListsComponent + Component objects
#   V1 option A: through association, components select(:id)  -> same objects, thinner Component rows
#   V2 A on join rows: has_many join rows select(ml_id, component_id), serializer reads component_id
#   V3 option C: one pluck of (monitoring_list_id, component_id) pairs, no AR objects
#   V4 lazy load: lazy_load_data, no `data` unless included; once without and once with the include_mapping preload
# Each variant runs the preload AND a real serializer pass, checks the output matches V0,
# for an org without and with can_see_tlp_amber_strict (the flag changes Rails' through-preload SQL),
# and reports queries, wall time, allocated Ruby objects and instantiated AR records per class.
# Runs inside a rolled-back transaction — non-destructive.
#   bin/rails runner .solve/scripts/seed-and-measure-ml-index-component-ids.rb

def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def measure
  queries = 0
  sqls = []
  instantiated = Hash.new(0)
  subs = [
    ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      unless payload[:name] == 'SCHEMA' || payload[:sql] =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i
        queries += 1
        sqls << payload[:sql].squish.truncate(220)
      end
    end,
    ActiveSupport::Notifications.subscribe('instantiation.active_record') do |*, payload|
      instantiated[payload[:class_name]] += payload[:record_count]
    end
  ]
  GC.start
  allocated_before = GC.stat(:total_allocated_objects)
  t = clock
  result = yield
  seconds = clock - t
  allocated = GC.stat(:total_allocated_objects) - allocated_before
  [
    result,
    { queries: queries, seconds: seconds.round(3), allocated: allocated, instantiated: instantiated, sqls: sqls }
]
ensure
  subs&.each { |sub| ActiveSupport::Notifications.unsubscribe(sub) }
end

MonitoringList.has_many(
  :probe_visible_component_ids_only,
  -> { visible.select(:id) },
  through: :monitoring_lists_components,
  source: :component
)
MonitoringList.has_many(
  :probe_visible_component_links,
  lambda {
    where(component_id: Component.visible.select(:id)).select(:monitoring_list_id, :component_id).order(:component_id)
  },
  class_name: 'MonitoringListsComponent'
)

class ProbeV0Serializer < ApplicationSerializer
  set_type('monitoringLists')
  has_many(:components) { |ml| ml.visible_components.sort_by(&:id) }
end

class ProbeV1Serializer < ApplicationSerializer
  set_type('monitoringLists')
  has_many(:components) { |ml| ml.probe_visible_component_ids_only.sort_by(&:id) }
end

class ProbeV2Serializer < ApplicationSerializer
  set_type('monitoringLists')
  has_many(:components, record_type: :components, id_method_name: :component_id, &:probe_visible_component_links)
end

class ProbeV3Serializer < ApplicationSerializer
  set_type('monitoringLists')
  has_many(:components, record_type: :components, id_method_name: :itself) do |ml, params|
    params[:visible_component_ids].fetch(ml.id, [])
  end
end

class ProbeV4Serializer < ApplicationSerializer
  set_type('monitoringLists')
  has_many(:components, lazy_load_data: true, links: { self: ->(ml) { "/monitoringLists/#{ml.id}/components" } }) do |ml|
    ml.visible_components.sort_by(&:id)
  end
end

def serialize(serializer, lists, params = {})
  serializer.new(lists, fields: { monitoringLists: [:components] }, params: params, is_collection: true)
    .serializable_hash[:data]
    .to_h { |row| [row[:id], row[:relationships][:components][:data]] }
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    seeder = DatabaseSeeder.new(
      organizations: 1,
      users: 50,
      memberships_per_user: 1..1,
      component_vendors: 2_000,
      component_names: 5_000,
      components: 200_000,
      notifications: 0,
      monitoring_list_per_org: 200,
      subscribers_per_ml: 1..1,
      components_per_ml: 1_000..2_000,
      inbox_items: 0,
      support_dropped_events: 0,
      ml_events_per_org: 0,
      notification_events_per_org: 0,
      admin_expiry_items_per_org: 0
    )
    seeder.run
    %w[components monitoring_lists_components monitoring_lists].each do |table|
      ActiveRecord::Base.connection.execute("ANALYZE vilocifyportal.#{table}")
    end

    ml_ids = seeder.monitoring_list_ids
    membership = Membership.unscoped.where(organization_id: seeder.org_ids.first).detect do |m|
      m.permissions.include?('read:org:monitoring_lists') && m.permissions.include?('read:components')
    end
    links = MonitoringListsComponent.unscoped.where(monitoring_list_id: ml_ids).count
    distinct = MonitoringListsComponent.unscoped.where(monitoring_list_id: ml_ids).distinct.count(:component_id)
    puts("lists=#{ml_ids.size} links=#{links} distinct components=#{distinct} membership=#{membership.id}")
    puts

    [false, true].each do |can_see_tlp_amber_strict|
      Organization.unscoped.where(id: seeder.org_ids.first).update_all(can_see_tlp_amber_strict:)
      membership = Membership.unscoped.find(membership.id)
      puts("===== organization can_see_tlp_amber_strict=#{can_see_tlp_amber_strict}")
      Current.set_from_membership(membership) do
        puts(
          "read:components=#{Current.permissions.include?('read:components')} " \
            "read:tlp_amber_strict=#{Current.permissions.include?('read:tlp_amber_strict')}"
        )
        puts("Component.visible: #{Component.visible.to_sql.truncate(300)}")
        puts(
          'visible links in page: ' \
            "#{MonitoringListsComponent.where(monitoring_list_id: ml_ids, component: Component.visible).count}"
        )
        puts
        base = -> { MonitoringList.visible.where(id: ml_ids).order(:id) }

        variants = {
          'V0 current' => lambda {
            serialize(ProbeV0Serializer, base.call.includes(:visible_components).load)
          },
          'V1 A select(:id)' => lambda {
            serialize(ProbeV1Serializer, base.call.includes(:probe_visible_component_ids_only).load)
          },
          'V2 A join rows' => lambda {
            serialize(ProbeV2Serializer, base.call.includes(:probe_visible_component_links).load)
          },
          'V3 C pluck' => lambda {
            lists = base.call.load
            ids = MonitoringListsComponent
              .where(monitoring_list: lists, component: Component.visible)
              .order(:component_id)
              .pluck(:monitoring_list_id, :component_id)
              .group_by(&:first)
              .transform_values { |pairs| pairs.map(&:last) }
            serialize(ProbeV3Serializer, lists, visible_component_ids: ids)
          },
          'V4 lazy' => lambda {
            serialize(ProbeV4Serializer, base.call.load)
          },
          'V4 lazy + preload' => lambda {
            serialize(ProbeV4Serializer, base.call.includes(:visible_components).load)
          }
        }

        reference = nil
        variants.each do |label, run|
          2.times do |i|
            output, stats = measure(&run)
            reference ||= output
            puts(
              "#{label.ljust(18)} run#{i + 1} same_as_V0=#{output == reference} " \
                "queries=#{stats[:queries]} seconds=#{stats[:seconds]} allocated=#{stats[:allocated]} " \
                "instantiated=#{stats[:instantiated].sort.to_h} total_ids=#{output.values.sum { it&.size.to_i }}"
            )
            stats[:sqls].each { |sql| puts("    SQL #{sql}") } if i.zero?
          end
        end
      end
    end

    raise(ActiveRecord::Rollback)
  end
end
