# bin/rails runner .solve/tasks/2026-10-20-changelog-check-issue/current.rb
# Step: measure what caching the changelog would save
# Checks: ms per call for the fs+JSON work vs a full request, on the largest release (2.6.1, 62 KB)
# Look at: the "cacheable" rows as a share of the "full request" rows
changelog = ActionJsonApi::Documentation::Changelog
runs = 200
ms = ->(&block) { (Benchmark.realtime { runs.times(&block) } / runs * 1000).round(3) }

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host = 'localhost'
session.get('/openapi/changelog/2.6.1')
session.get('/documentation/changelog')
puts("warmup statuses: #{session.response.status}")

puts("cacheable  newest_release_first:   #{ms.call { changelog.newest_release_first }} ms")
puts("cacheable  find_release('2.6.1'):  #{ms.call { changelog.find_release('2.6.1') }} ms")
puts("full request GET /documentation/changelog:  #{ms.call { session.get('/documentation/changelog') }} ms")
puts("full request GET /openapi/changelog/2.6.1:  #{ms.call { session.get('/openapi/changelog/2.6.1') }} ms")
puts("last status: #{session.response.status}")
