# This is the base class for controllers in the application.
# Code in the before or after blocks will run on every request
class ApplicationController
  include Sinatra::Delegator
  extend Sinatra::Delegator

  before do
    @request_start = Time.now
  end

  after do
    duration = Time.now - @request_start
    full_path = "#{request.request_method} #{request.path}"
    full_path += "?#{request.query_string}" unless request.query_string.to_s.empty?
    settings.monitor.log_request(full_path: full_path,
                                 status: response.status,
                                 duration: duration,
                                 user: %w[syphax admin youba].sample,
                                 month_key: %w[2019-01 2019-02 2019-03 2020-01 2025-02].sample)
  end

  get '/monitoring/global/stats' do
    content_type :json
    settings.monitor.global_stats.to_json
  end

  get '/monitoring/month/stats' do
    month = params[:month].presence || Time.now.strftime('%Y-%m')
    content_type :json
    settings.monitor.monthly_stats(month).to_json
  end

  get '/monitoring/memory/stats' do
    content_type :json
    settings.monitor.memory_stats.to_json
  end

  get '/monitoring/clear' do
    settings.monitor.clear_all_logs
    content_type :json
    { message: 'All logs cleared' }.to_json
  end

end
