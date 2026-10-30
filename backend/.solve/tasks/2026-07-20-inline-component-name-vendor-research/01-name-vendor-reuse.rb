puts('Component::Name — components per name:')
Component.joins(:component_name).group('component_names.name').order(Arel.sql('count(*) desc')).limit(50).count
  .each { |name, count| puts("  #{name} => #{count}") }

puts('Component::Vendor — components per vendor:')
Component.joins(:component_vendor).group('component_vendors.name').order(Arel.sql('count(*) desc')).limit(50).count
  .each { |name, count| puts("  #{name} => #{count}") }
