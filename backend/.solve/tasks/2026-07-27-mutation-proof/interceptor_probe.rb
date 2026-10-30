# RAILS_ENV=test bin/rails runner .solve/tasks/2026-07-27-mutation-proof/interceptor_probe.rb
# Mimics the teardown that InterceptorTestCase.tests(...) used to run on main.
require('mail')
ActionMailer::Base.eager_load!
puts "mail gem: #{Gem.loaded_specs['mail'].version}"
puts "before: #{Mail.class_variable_get(:@@delivery_interceptors).inspect}"

ActionMailer::Base.register_interceptor(Interceptors::VilocifyTagInterceptor)
puts "after register (dedup?): #{Mail.class_variable_get(:@@delivery_interceptors).inspect}"

ActionMailer::Base.unregister_interceptor(Interceptors::VilocifyTagInterceptor)
puts "after unregister: #{Mail.class_variable_get(:@@delivery_interceptors).inspect}"
puts "=> globally configured interceptor still active? #{Mail.class_variable_get(:@@delivery_interceptors).any?}"
