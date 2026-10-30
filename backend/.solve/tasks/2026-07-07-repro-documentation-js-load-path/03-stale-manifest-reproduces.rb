require('json')
manifest = 'public/backend-assets/.manifest.json'
backup = "#{manifest}.repro-backup"
File.write(backup, File.read(manifest))
entries = JSON.parse(File.read(manifest))
entries.delete_if { |logical, _| logical.start_with?('documentation.js') }
File.write(manifest, JSON.generate(entries))
system('bin/rails test test/integration/documentation_controller_test.rb')
File.write(manifest, File.read(backup))
File.delete(backup)
