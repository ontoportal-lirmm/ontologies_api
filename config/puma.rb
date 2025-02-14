workers Integer(ENV['WEB_CONCURRENCY'] || 0)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count
pid = Process.pid
env = ENV['RACK_ENV'] || ENV['ENVIRONMENT'] || 'production'

environment env
port 9393
if env == 'development'
  puts "Reload enabled"
  # Use the `listen` gem to reload the application when files change
  require 'listen'

  listener = Listen.to('.', only: /\.rb$/) do |modified, added, removed|
    # Reload the application when Ruby files change
    Process.kill('SIGUSR2', pid)
  end
  listener.start
end