class APIMonitor
  class ErrorStats < ObjectStats
    set_key 'monthly_status'

    def initialize(redis:)
      super(redis: redis)
    end

    def total_status_count
      statuses = {}
      status_count_by_month.each_value do |status|
        status.each do |code, count|
          statuses[code] ||= 0
          statuses[code] += count.to_i
        end
      end
      statuses
    end

    def status_count_by_month
      @status_count_by_month ||= redis.keys(key).each_with_object({}) do |key, result|
        month = key.split(':').last
        result[month] = redis.hgetall(key)
      end
    end

    def month_status_count(month)
      redis.keys("#{self.class.local_key.gsub('*', month)}:*").each_with_object({}) do |key, result|
        endpoint = key.split(':').last
        result[endpoint] = redis.hgetall(key)
      end
    end
  end
end
