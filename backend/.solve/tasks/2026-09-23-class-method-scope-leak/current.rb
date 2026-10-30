# ruby .solve/tasks/2026-09-23-class-method-scope-leak/current.rb
MAIN = '/home/felix/Code/Vilocify/vilocify-portal'.freeze
ENV['RAILS_ENV'] = 'test'
ENV['PARALLEL_WORKERS'] = '1'
$LOAD_PATH.unshift("#{MAIN}/test")
require('test_helper')

HITS = Hash.new(0)
Spy = Module.new do
  %i[each_with_current json_api_filter_method].each do |name|
    define_method(name) do |*args, **kwargs, &block|
      Thread.current[:spy] ||= current_scope
      super(*args, **kwargs, &block)
    ensure
      Thread.current[:spy] = nil if Thread.current[:spy].equal?(current_scope)
    end
  end
  define_method(:all) do |*args, **kwargs|
    frames = caller_locations(1, 4)
    if current_scope && current_scope.equal?(Thread.current[:spy]) && frames.none? { |l| l.path.end_with?('relation/delegation.rb') }
      frame = caller_locations.find { |l| l.path.start_with?("#{MAIN}/app", __FILE__) }
      HITS[frame.to_s] += 1 unless frame.to_s.match?(/organization\.rb:33|json_api_filter\.rb/)
    end
    super(*args, **kwargs)
  end
end
[Organization, *ApplicationRecord.descendants.select { |m| m.respond_to?(:json_api_filter_method) }].each { |m| m.singleton_class.prepend(Spy) }
Minitest.after_run { puts(HITS.empty? ? 'no leaked same-model queries' : HITS.sort_by { -_2 }.map { |k, v| "#{v} #{k}" }) }
Organization.active.each_with_current { Organization.count and break }
Dir["#{MAIN}/test/{models,integration,jobs,controllers}/**/*_test.rb"].each { |file| require(file) }
