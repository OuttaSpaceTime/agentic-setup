# bin/rails runner .solve/tasks/2026-08-05-pg-error-repro/repro.rb

attempt = lambda do |label, &block|
  puts "\n== #{label}"
  begin
    block.call
    puts '   (no error raised)'
  rescue ActiveRecord::StatementInvalid => e
    puts "   #{e.cause.class}"
    puts "   #{e.cause.message.lines.map(&:strip).reject(&:empty?).join(' | ')}"
  rescue StandardError => e
    puts "   #{e.class}: #{e.message.lines.first.strip}"
  end
end

conn = ActiveRecord::Base.connection

puts "1) app path: Notification.dynamic_where('updated_at', '<', <Integer from cursor>)"
puts "   SQL: #{Notification.dynamic_where('updated_at', '<', 123).to_sql}"
attempt.('execute it') { Notification.dynamic_where('updated_at', '<', 123).to_a }

puts "\n2) app path: same, with a garbage String from a tampered cursor"
puts "   SQL: #{Notification.dynamic_where('updated_at', '<', '2026-08-15T00:00:00').to_sql}"
attempt.('execute it') { Notification.dynamic_where('updated_at', '<', 'nonsense').to_a }

attempt.('3) hand-written SQL: bare integer against a timestamp column') do
  conn.select_all('SELECT id FROM notifications WHERE notifications.updated_at < 123')
end

attempt.('4) hand-written SQL: unquoted ISO timestamp') do
  conn.select_all('SELECT id FROM notifications WHERE updated_at < 2026-08-15T00:00:00')
end

attempt.('5) hand-written SQL: unqualified updated_at across a join') do
  conn.select_all(
    'SELECT memberships.id FROM memberships INNER JOIN users ON users.id = memberships.user_id ' \
    'WHERE updated_at < now()'
  )
end

attempt.('6) FK violation like ComponentPullJob rescues (rolled back)') do
  ActiveRecord::Base.transaction do
    id = conn.select_value('SELECT id FROM components LIMIT 1')
    raise('no components in dev db') unless id

    conn.execute("UPDATE components SET replaced_by_component_id = 383952 WHERE id = #{id}")
  ensure
    raise(ActiveRecord::Rollback)
  end
end

attempt.('7) FOR UPDATE NOWAIT on a row locked by another connection') do
  id = Current.without_organization_and_membership_scopes { ComponentRequest.unscoped.pick(:id) }
  raise('no component_requests in dev db') unless id

  holder_ready = Queue.new
  release = Queue.new
  holder = Thread.new do
    ActiveRecord::Base.connection_pool.with_connection do |other|
      other.transaction do
        other.select_value("SELECT id FROM component_requests WHERE id = #{id} FOR UPDATE")
        holder_ready << true
        release.pop
      end
    end
  end
  holder_ready.pop

  begin
    ActiveRecord::Base.transaction do
      conn.select_value("SELECT id FROM component_requests WHERE id = #{id} FOR UPDATE NOWAIT")
    end
  ensure
    release << true
    holder.join
  end
end

attempt.('8) statement timeout') do
  puts "   database.yml variables: #{ActiveRecord::Base.connection_db_config.configuration_hash[:variables].inspect}"
  ApplicationRecord.with_statement_timeout('100ms') { conn.select_value('SELECT pg_sleep(1)') }
end
