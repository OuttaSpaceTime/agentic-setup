[Time.zone.now, Date.new(2026,1,1), 42, 'v1.2'].each do |v|
  begin
    puts format('%-28s .acts_like_time? => %s', v.class, v.acts_like_time?.inspect)
  rescue StandardError => e
    puts format('%-28s .acts_like_time? RAISES %s', v.class, e.class)
  end
end
