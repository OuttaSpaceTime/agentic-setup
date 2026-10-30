# bin/rails test .solve/tasks/2026-07-29-asrelationship-sql/reveal_defeated_test.rb
require 'test_helper'

class RevealDefeatedTest < ActiveSupport::TestCase
  test('outer AsRelationship re-scope defeats an inner tlp reveal') do
    restricted = components(:tlp_restricted_component)

    inner = Component.unscope(where: :tlp_amber_strict).where(id: restricted.id)
    outer = Component::AsRelationship.where(id: inner)

    puts "inner reveals restricted?  #{inner.exists?(restricted.id)}"
    puts "outer still shows it?      #{outer.exists?(restricted.id)}"

    assert(inner.exists?(restricted.id))
    assert_not(outer.exists?(restricted.id))
  end
end
