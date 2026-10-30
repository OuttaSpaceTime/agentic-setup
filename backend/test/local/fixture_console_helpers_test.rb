require('test_helper')

class FixtureConsoleHelpersTest < ActiveSupport::TestCase
  setup do
    unless defined?(FixtureConsoleHelpers)
      Rails.logger.silence { capture_io { Rails.application.load_console } }
      # ActiveRecord's console block broadcasts Rails.logger to STDERR for good, spamming every later test
      Rails.logger.broadcasts.each do |sink|
        Rails.logger.stop_broadcasting_to(sink) if ActiveSupport::Logger.logger_outputs_to?(sink, $stderr, $stdout)
      end
    end

    @main = TOPLEVEL_BINDING.eval('self')
    @completor = IRB::RegexpCompletor.new
  end

  def complete(preposing, target)
    @completor.completion_candidates(preposing, target, '', bind: TOPLEVEL_BINDING)
  end

  def labels_in(fixture_file)
    ActiveRecord::FixtureSet::File.open(Rails.root.join('test/fixtures', fixture_file)).map { ":#{it.first}" }
  end

  test('resolves a fixture label to the record') do
    assert_equal(organizations(:org_a), @main.organizations(:org_a))
  end

  test('resolves several fixture labels to an array of records') do
    assert_equal([organizations(:org_a), organizations(:org_b)], @main.organizations(:org_a, :org_b))
  end

  test('names the fixture and the environment when the label is unknown') do
    error = assert_raises(ActiveRecord::RecordNotFound) { @main.organizations(:org_nonexistent) }

    assert_equal('Organization fixture :org_nonexistent was not found in the current test database', error.message)
  end

  test('completes only the labels of the fixture file behind the helper being typed') do
    assert_equal(labels_in('organizations.yml').grep(/\A:or/), complete('organizations(', ':or'))
  end

  test('completes every label of the fixture file for a bare colon') do
    assert_equal(labels_in('organizations.yml'), complete('organizations(', ':'))
  end

  test('completes the labels of a fixture file nested in a directory') do
    assert_equal(
      labels_in('notification/vulnerabilities.yml').grep(/\A:cve_2021/),
      complete('notification_vulnerabilities(', ':cve_2021')
    )
  end

  test('completes a label typed as a later argument') do
    assert_equal(labels_in('organizations.yml'), complete('organizations(:org_a, ', ':'))
  end

  test('completes a label inside a surrounding method call') do
    assert_equal(labels_in('organizations.yml'), complete('Organization.unscoped.find(organizations(', ':'))
  end

  test('skips the DEFAULTS block because Rails never loads it as a record') do
    assert_includes(labels_in('inbox/items.yml'), ':DEFAULTS')

    assert_equal(labels_in('inbox/items.yml') - [':DEFAULTS'], complete('inbox_items(', ':'))
  end

  test('falls back to IRB completion for a method that is no fixture helper') do
    assert_equal(Symbol.all_symbols.map(&:inspect).grep(/\A:org_a/), complete('unrelated_method(', ':org_a'))
  end

  test('completes nothing before a symbol is typed') do
    assert_empty(complete('organizations(', ''))
  end

  test('names the fixture label a record was loaded from') do
    assert_equal(:org_a, organizations(:org_a).fixture_name)
  end

  test('names a label the fixture helper resolves back to the same record') do
    record = memberships(:ansgar_as_user_in_a)

    assert_equal(record, @main.memberships(record.fixture_name))
  end

  test('names the label of an STI record whose fixture file is named after the base class') do
    record = inbox_item_monitoring_list_subscription_changeds(:added_one)

    assert_instance_of(Inbox::Item::MonitoringList::SubscriptionChanged::Added, record)
    assert_equal(:added_one, record.fixture_name)
  end

  test('names nothing for a record created outside the fixtures') do
    assert_nil(Organization.create!(name: 'Organization Without A Fixture').fixture_name)
  end

  test('names nothing for a record that was never saved') do
    assert_nil(Organization.new.fixture_name)
  end

  test('leaves the Rails logger writing to the log file only so later tests keep a quiet console') do
    assert_not(ActiveSupport::Logger.logger_outputs_to?(Rails.logger, $stderr, $stdout))
  end
end
