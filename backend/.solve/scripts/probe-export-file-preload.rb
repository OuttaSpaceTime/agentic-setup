# Probe: which include key makes `export.file` query-free?
#   bin/rails runner .solve/scripts/probe-export-file-preload.rb

def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def measure
  count = 0
  sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
    count += 1 unless payload[:name] == 'SCHEMA' || payload[:sql] =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i
  end
  t = clock
  yield
  [count, clock - t]
ensure
  ActiveSupport::Notifications.unsubscribe(sub)
end

def attach_dummy_file(record)
  io = StringIO.new('dummy,xlsx,content')
  io.rewind
  record.file.attach(io: io, filename: 'export.xlsx', content_type: 'application/vnd.ms-excel')
end

Current.without_organization_and_membership_scopes do
  ActiveRecord::Base.transaction do
    org = Organization.create!(name: "ProbeOrg #{SecureRandom.hex(6)}")
    period = org.consumption_periods.create!(period: Date.current..1.year.from_now.to_date)
    period.orders.create!(name: 'Individual', membership_request_credit: 5, api_request_credit: 0, component_request_request_credit: 0)
    user = User.create!(name: 'Probe', email: "probe#{SecureRandom.hex(6)}@example.com")
    membership = Membership.create!(user:, organization: org, role: 'user', invitation_state: 'accepted', expires_at: 2.years.from_now)

    exports = Array.new(20) do
      e = Membership.all.find(membership.id).exports.create!(state: :success)
      attach_dummy_file(e)
      e
    end
    puts("exports: #{exports.size}")

    # naive: touch each export's file
    naive = measure do
      MonitoringList::Export.where(id: exports.map(&:id)).each { |e| e.file.filename }
    end
    puts("NAIVE  each .file.filename:        queries=#{naive[0]}")

    # preload with file_blob (through)
    gc = measure do
      MonitoringList::Export.where(id: exports.map(&:id)).includes(:file_blob).each { |e| e.file.filename }
    end
    puts("PRELOAD :file_blob:                queries=#{gc[0]}")

    # preload with file_attachment: :blob
    gc2 = measure do
      MonitoringList::Export.where(id: exports.map(&:id)).includes(file_attachment: :blob).each { |e| e.file.filename }
    end
    puts("PRELOAD :file_attachment, :blob:   queries=#{gc2[0]}")

    # does .success? also hit DB? (should not, it's a state column)
    s = measure do
      MonitoringList::Export.where(id: exports.map(&:id)).each { |e| e.success? }
    end
    puts("NAIVE  each .success?:             queries=#{s[0]}")

    raise(ActiveRecord::Rollback)
  end
end
