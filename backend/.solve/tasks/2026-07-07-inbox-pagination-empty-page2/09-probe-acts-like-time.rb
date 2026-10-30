require 'date'
twz = Time.zone.now
d = Date.new(2026, 1, 1)
[twz, d, 42, 'v1.2'].each do |v|
  gate = v.acts_like?(:time)
  encoded = gate ? v.iso8601(6) : v
  puts format('%-28s acts_like?(:time)=%-5s => %s', v.class, gate, encoded.inspect)
end
