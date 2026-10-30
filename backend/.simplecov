# Local-only, untracked: bin/test sets TRACK_TESTS so it can record the per-test
# map that resolves an app file to the tests covering it. The respond_to? guard
# keeps older branches (simplecov 0.22) loading this file without warning.
if ENV.key?('TRACK_TESTS') && SimpleCov.respond_to?(:track_tests)
  # Gems loaded before Coverage starts are never instrumented, so each per-test
  # snapshot copies project code only. Mirrors config/application.rb.
  require('rails')
  %w[
    active_record/railtie
    action_controller/railtie
    action_view/railtie
    action_mailer/railtie
    active_job/railtie
    rails/test_unit/railtie
    active_storage/engine
  ].each { require(it) }
  Bundler.require(:default, :test)
  SimpleCov.track_tests
  # bin/test reads only coverage/coverage.json: skip the Cobertura report and every status line.
  SimpleCov.at_exit do
    result = SimpleCov.result
    next unless result && SimpleCov.merge_finalization_owner?

    SimpleCov::Formatter::JSONFormatter.new(silent: true).format(result)
  end
  require('openapi_first/test')
  OpenapiFirst::Test.configuration.logger = Logger.new(File::NULL)
end
