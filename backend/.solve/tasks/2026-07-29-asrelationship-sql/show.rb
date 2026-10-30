# bin/rails runner .solve/tasks/2026-07-29-asrelationship-sql/show.rb
puts "=== outer scope on a plain id list ==="
puts Component::AsRelationship.where(id: [1, 2, 3]).to_sql
puts
puts "=== outer .where(id: <inner relation>) — the controller pattern ==="
puts Component::AsRelationship.where(id: Component::AsRelationship.all).to_sql
