# bin/rails runner .solve/tasks/2026-08-05-priorities-migration/03-probe-dropped-column-bytes.rb
c = ActiveRecord::Base.connection

def canary_bytes(conn)
  conn.select_value(<<~SQL.squish)
    SELECT count(*) FROM heap_page_items(get_raw_page('recover_probe', 0))
    WHERE t_data IS NOT NULL AND encode(t_data, 'escape') LIKE '%CANARY%'
  SQL
end

c.execute('CREATE EXTENSION IF NOT EXISTS pageinspect')
c.execute('DROP TABLE IF EXISTS recover_probe')
c.execute('CREATE TABLE recover_probe (id integer, secret text)')
c.execute("INSERT INTO recover_probe VALUES (1, 'CANARY_VALUE_XYZ')")

puts "canary tuples, before drop:      #{canary_bytes(c)}"
c.execute('ALTER TABLE recover_probe DROP COLUMN secret')
puts "canary tuples, after DROP COLUMN: #{canary_bytes(c)}"
c.execute('ALTER TABLE recover_probe ALTER COLUMN id TYPE bigint')
puts "canary tuples, after type rewrite: #{canary_bytes(c)}"

c.execute('DROP TABLE recover_probe')
