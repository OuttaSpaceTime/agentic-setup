# Covers the columns main's fixtures leave non-NULL, so the manual before/after cannot show them.
#   bin/rails runner .solve/scripts/prove_not_null_backfills.rb
%w[
  20260916135927_backfill_nulls_in_api_tokens
  20260916140203_add_not_null_constraints_to_api_tokens
  20260916140213_backfill_nulls_in_component_requests
  20260916140222_add_not_null_constraints_to_component_requests
  20260916140232_backfill_nulls_in_components
  20260916140239_add_not_null_constraints_to_components
  20260916140308_backfill_nulls_in_notification_vulnerabilities
  20260916140316_add_not_null_constraints_to_notification_vulnerabilities
  20260918035246_backfill_null_eol_reached_in_components
  20260918035252_add_not_null_constraint_to_eol_reached_in_components
].each { |file| require(Rails.root.join('db/migrate', file)) }

REVERSE_ORDER = [
  AddNotNullConstraintToEolReachedInComponents,
  AddNotNullConstraintsToNotificationVulnerabilities,
  AddNotNullConstraintsToComponents,
  AddNotNullConstraintsToComponentRequests,
  AddNotNullConstraintsToApiTokens
].freeze

FORWARD_ORDER = [
  BackfillNullsInApiTokens,
  AddNotNullConstraintsToApiTokens,
  BackfillNullsInComponentRequests,
  AddNotNullConstraintsToComponentRequests,
  BackfillNullsInComponents,
  AddNotNullConstraintsToComponents,
  BackfillNullsInNotificationVulnerabilities,
  AddNotNullConstraintsToNotificationVulnerabilities,
  BackfillNullEolReachedInComponents,
  AddNotNullConstraintToEolReachedInComponents
].freeze

TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'.freeze
CREATED_AT_SEED = '2021-02-03 04:05:06'.freeze
UPDATED_AT_SEED = '2022-03-04 05:06:07'.freeze
DATE_FORMAT = 'YYYY-MM-DD'.freeze
EOL_DATE_SEED = '2023-04-05'.freeze

connection = ActiveRecord::Base.connection
checks = []

def check(checks, label, actual, expected)
  checks << [label, actual, expected]
  puts("#{actual == expected ? 'PASS' : 'FAIL'} #{label} got=#{actual.inspect} expected=#{expected.inspect}")
end

ActiveRecord::Base.transaction do
  ActiveRecord::Migration.suppress_messages do
    REVERSE_ORDER.each { |migration| migration.new.migrate(:down) }
  end

  token_id = connection.select_value('SELECT id FROM api_tokens ORDER BY id LIMIT 1')
  request_id = connection.select_value('SELECT id FROM component_requests ORDER BY id LIMIT 1')
  vulnerability_id = connection.select_value('SELECT id FROM notification_vulnerabilities ORDER BY id LIMIT 1')
  strings_id, eol_null_id, eol_dated_id, created_id, updated_id, both_id =
    connection.select_values("SELECT id FROM components WHERE eol_date = 'infinity' ORDER BY id LIMIT 6")

  connection.execute("UPDATE api_tokens SET description = NULL WHERE id = '#{token_id}'")
  connection.execute(<<~SQL.squish)
    UPDATE component_requests
    SET component_name = NULL, version = NULL, vendor = NULL, url = NULL
    WHERE id = '#{request_id}'
  SQL
  connection.execute("UPDATE notification_vulnerabilities SET cve = NULL WHERE id = #{vulnerability_id}")
  connection.execute(<<~SQL.squish)
    UPDATE components SET name = NULL, version_info = NULL, vendor = NULL WHERE id = #{strings_id}
  SQL
  connection.execute("UPDATE components SET eol_date = NULL, eol_reached = NULL WHERE id = #{eol_null_id}")
  connection.execute(<<~SQL.squish)
    UPDATE components SET eol_date = '#{EOL_DATE_SEED}', eol_reached = NULL WHERE id = #{eol_dated_id}
  SQL
  connection.execute(<<~SQL.squish)
    UPDATE components SET created_at = NULL, updated_at = '#{UPDATED_AT_SEED}' WHERE id = #{created_id}
  SQL
  connection.execute(<<~SQL.squish)
    UPDATE components SET created_at = '#{CREATED_AT_SEED}', updated_at = NULL WHERE id = #{updated_id}
  SQL
  connection.execute("UPDATE components SET created_at = NULL, updated_at = NULL WHERE id = #{both_id}")

  ActiveRecord::Migration.suppress_messages do
    FORWARD_ORDER.each { |migration| migration.new.migrate(:up) }
  end

  token = connection.select_one("SELECT description FROM api_tokens WHERE id = '#{token_id}'")
  check(checks, 'api_tokens.description', token['description'], '')

  request = connection.select_one(<<~SQL.squish)
    SELECT component_name, version, vendor, url FROM component_requests WHERE id = '#{request_id}'
  SQL
  %w[component_name version vendor url].each do |column|
    check(checks, "component_requests.#{column}", request[column], '')
  end

  vulnerability = connection.select_one("SELECT cve FROM notification_vulnerabilities WHERE id = #{vulnerability_id}")
  check(checks, 'notification_vulnerabilities.cve', vulnerability['cve'], '')

  strings = connection.select_one("SELECT name, version_info, vendor FROM components WHERE id = #{strings_id}")
  %w[name version_info vendor].each do |column|
    check(checks, "components.#{column}", strings[column], '')
  end

  eol_null = connection.select_one(<<~SQL.squish)
    SELECT eol_date::text AS eol_date, eol_reached FROM components WHERE id = #{eol_null_id}
  SQL
  check(checks, 'components.eol_date (was NULL, eol_reached NULL)', eol_null['eol_date'], 'infinity')
  check(checks, 'components.eol_reached (was NULL, eol_date NULL)', eol_null['eol_reached'], false)

  eol_dated = connection.select_one(<<~SQL.squish)
    SELECT to_char(eol_date, '#{DATE_FORMAT}') AS eol_date, eol_reached
    FROM components WHERE id = #{eol_dated_id}
  SQL
  check(checks, 'components.eol_date (dated, eol_reached NULL)', eol_dated['eol_date'], EOL_DATE_SEED)
  check(checks, 'components.eol_reached (was NULL, eol_date dated)', eol_dated['eol_reached'], false)

  created = connection.select_one(<<~SQL.squish)
    SELECT to_char(created_at, '#{TIMESTAMP_FORMAT}') AS created_at FROM components WHERE id = #{created_id}
  SQL
  check(checks, 'components.created_at (was NULL) takes updated_at', created['created_at'], UPDATED_AT_SEED)

  updated = connection.select_one(<<~SQL.squish)
    SELECT to_char(updated_at, '#{TIMESTAMP_FORMAT}') AS updated_at FROM components WHERE id = #{updated_id}
  SQL
  check(checks, 'components.updated_at (was NULL) takes created_at', updated['updated_at'], CREATED_AT_SEED)

  both = connection.select_one(<<~SQL.squish)
    SELECT created_at IS NOT NULL AND updated_at IS NOT NULL AS filled, created_at = updated_at AS equal
    FROM components WHERE id = #{both_id}
  SQL
  check(checks, 'components.created_at/updated_at (both NULL) filled', both['filled'], true)
  check(checks, 'components.created_at/updated_at (both NULL) equal', both['equal'], true)

  failed = checks.count { |_, actual, expected| actual != expected }
  puts("\n#{checks.size - failed}/#{checks.size} checks passed")
  raise(ActiveRecord::Rollback)
end
