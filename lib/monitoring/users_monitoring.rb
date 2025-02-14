class APIMonitor
  class UserStats < ObjectStats
    set_key 'user_requests'

    def initialize(redis:)
      super(redis: redis)
    end

    def total_requests_count
      users_count = {}
      requests_count_by_month.map do |username, months|
        users_count[username] = months.values.map { |month| month.values.sum }.sum
      end
      users_count
    end

    def requests_count_by_month
      @cout_by_month ||= redis.keys(key).each_with_object({}) do |key, result|
        username = key.split(':')[3]
        year_month = key.split(':')[2]
        result[username] ||= {}
        result[username][year_month] ||= {}
        redis.hgetall(key).each do |endpoint, count|
          result[username][year_month][endpoint] = count.to_i
        end
      end
    end

    def latest_requests_count
      requests_count_by_month.transform_values do |months|
        months.keys.sort.last
      end
    end

    def endpoint_request_count
      endpoints_count = {}
      requests_count_by_month.each_value do |months|
        months.each_value do |endpoints|
          endpoints.each do |endpoint, count|
            endpoints_count[endpoint] ||= 0
            endpoints_count[endpoint] += count
          end
        end
      end
      endpoints_count
    end

    def month_user_request_count(month)
      return @month_request_count[month] if @month_request_count && @month_request_count[month]

      @month_request_count ||= {}
      user_keys = redis.keys(key.gsub('*', "#{month}:*"))
      user_stats = {}
      user_keys.each do |key|
        user_id = key.split(':').last
        user_stats[user_id] = redis.hgetall(key)
      end
      @month_request_count[month] = user_stats
    end

    def month_request_count(month)
      month_user_request_count(month).transform_values do |endpoints|
        endpoints.values.map(&:to_i).sum
      end
    end

    def month_endpoint_request_count(month)
      month_user_request_count(month).each_with_object({}) do |(_user_id, endpoints), result|
        endpoints.each do |endpoint, count|
          result[endpoint] ||= 0
          result[endpoint] += count.to_i
        end
      end
    end
  end
end
