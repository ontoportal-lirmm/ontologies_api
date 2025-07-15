require './app.rb'
run Sinatra::Application

map '/sidekiq' do
  run Sidekiq::Web
end