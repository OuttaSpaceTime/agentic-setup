require "csv"
dir = File.dirname(__FILE__)
rows = CSV.read(File.join(dir, "data.csv"), headers: true)
val = ->(r, c) { r[c].to_s.tr(",", ".").to_f }
pts = rows.headers[1..16]
bad = rows.reject { |r| (pts.sum { |c| val.(r, c) } - val.(r, "gesamt")).abs < 0.5 }
puts "transcription mismatches: #{bad.map { |r| r['name'] }.join(', ').then { |s| s.empty? ? 'none' : s }}"
puts "sheet totals != 100: #{rows.reject { |r| val.(r, 'gesamt') == 100 }.map { |r| r['name'] }.join(', ')}"
puts
rows.headers[3..16].each do |lap|
  bids = rows.map { |r| [r["name"], val.(r, lap)] }.reject { |_, p| p <= 0 }.sort_by { |_, p| -p }
  next if bids.empty?
  puts "#{lap}  -- #{bids.size} bidders, top bid #{bids.first[1].round}"
  bids.each { |n, p| puts "  #{p.round.to_s.rjust(4)}  #{n}#{n == 'Felix Eschey' ? '   <= YOU' : ''}" }
  puts
end
