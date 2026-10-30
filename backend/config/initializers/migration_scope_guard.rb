module MigrationScopeGuard
  class Violation < StandardError; end

  NIL_ORGANIZATION_PREDICATE = /"\w+"\."organization_id" IS NULL/
  UNRESTRICTED_TLP_PREDICATE = /"\w+"\."tlp_amber_strict" = FALSE/

  SCOPE_MESSAGE = 'Migrations run with Current.organization == nil, so the OrgScoped default_scope narrows to ' \
    '`organization_id IS NULL` and matches no rows. Wrap the query in ' \
    '`::Current.set(organization: ...)` or `::Current.without_organization_and_membership_scopes`.'.freeze

  TLP_MESSAGE = 'The TlpAmberStrict default_scope narrows to `tlp_amber_strict = FALSE`, so this migration ' \
    'silently skips restricted rows. Use `including_tlp_amber_strict` to cover them.'.freeze

  CBASE_MESSAGE = 'Reference `::Current`, not `Current`. Inside a migration the constant `Current` resolves to ' \
    'ActiveRecord::Migration::Current, not the app-level CurrentAttributes.'.freeze

  def self.skips_restricted_rows?(event)
    payload = event.payload

    UNRESTRICTED_TLP_PREDICATE.match?(payload[:sql]) ||
      payload[:binds].to_a.any? { it.name == 'tlp_amber_strict' && it.value == false }
  end

  def self.abort_on(message, statements)
    return if statements.empty?

    raise(Violation, [message, *statements.uniq].join("\n\n"))
  end

  module CaptureSql
    def exec_migration(conn, direction)
      unscoped = []
      restricted = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |event|
        sql = event.payload[:sql]
        unscoped << sql if NIL_ORGANIZATION_PREDICATE.match?(sql)
        restricted << sql if MigrationScopeGuard.skips_restricted_rows?(event)
      end

      begin
        super
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      MigrationScopeGuard.abort_on(SCOPE_MESSAGE, unscoped)
      MigrationScopeGuard.abort_on(TLP_MESSAGE, restricted)
    end
  end

  module CurrentConstant
    def method_missing(name, ...)
      raise(Violation, CBASE_MESSAGE) if ::Current.respond_to?(name)

      super
    end

    def respond_to_missing?(name, ...)
      ::Current.respond_to?(name) || super
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.prepend(MigrationScopeGuard::CaptureSql)
  ActiveRecord::Migration::Current.singleton_class.prepend(MigrationScopeGuard::CurrentConstant)
end
