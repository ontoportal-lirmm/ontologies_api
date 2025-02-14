class APIMonitor
  class RequestStats < ObjectStats
    set_key 'request_times'

    def initialize(redis:)
      super(redis: redis)
    end

    def total_avg_response_times
      results = {}
      calculate_response_times(redis).each_value do |endpoints|
        endpoints.each do |endpoint, times|
          results[endpoint] ||= {}
          results[endpoint][:p50] ||= []
          results[endpoint][:p95] ||= []
          results[endpoint][:p99] ||= []

          results[endpoint][:p50] << times[:p50]
          results[endpoint][:p95] << times[:p95]
          results[endpoint][:p99] << times[:p99]
        end
      end
      results.transform_values do |times|
        {
          p50: times[:p50].sum / times[:p50].length,
          p95: times[:p95].sum / times[:p95].length,
          p99: times[:p99].sum / times[:p99].length
        }
      end
    end

    def month_avg_response_times(month)
      result = {}
      redis.keys("#{key.gsub('*', month)}:*").each do |key|
        endpoint = key.split(':').last
        times = redis.zrange(key, 0, -1, with_scores: true)
        result[endpoint] = {
          p50: percentile(times, 50),
          p95: percentile(times, 95),
          p99: percentile(times, 99)
        }
      end
      result
    end

    private

    def calculate_response_times(redis)
      return @total_times if @total_times

      result = {}
      redis.keys(key).each do |key|
        month = key.split(':')[2]
        endpoint = key.split(':').last
        times = redis.zrange(key, 0, -1, with_scores: true)
        result[month] ||= {}
        result[month][endpoint] = {
          p50: percentile(times, 50),
          p95: percentile(times, 95),
          p99: percentile(times, 99)
        }
      end
      @total_times = result
    end

    def percentile(times, percent)
      return 0 if times.empty?

      k = (percent / 100.0) * times.length
      times[k.ceil - 1][1]
    end

  end
end
