require 'redis'
require 'json'
require 'connection_pool'
require 'securerandom'

class APIMonitor
  class ObjectStats
    attr_accessor :key, :redis
    @@key_prefix = 'monitoring'

    class << self
      attr_accessor :key

      def set_key(key)
        @key = "#{@@key_prefix}:#{key}:*"
      end

      def local_key
        @key
      end

    end

    def initialize(redis:)
      @redis = redis
    end

    def key
      self.class.local_key
    end

    def self.key(*keys)
      monitor_key(*keys)
    end

    def self.monitor_key(month, optional_key = nil)
      if optional_key.nil?
        local_key.gsub('*', month)
      else
        local_key.gsub('*', "#{month}:#{optional_key}")
      end
    end

    def self.record(multi, data = {})
      raise NotImplementedError
    end

  end

  def initialize(redis_url = nil, pool_size: 5)
    @key_prefix = 'monitoring'
    @redis_pool = ConnectionPool.new(size: pool_size) {
      Redis.new(url: redis_url || ENV['REDIS_URL'] || 'redis://localhost:6379')
    }
  end

  def clear_month_logs(month)
    @redis_pool.with do |redis|
      keys = redis.keys("#{@key_prefix}:*:#{month}")
      keys.each do |key|
        redis.del(key)
      end
    end
  end

  def clear_all_logs
    @redis_pool.with do |redis|
      keys = redis.keys("#{@key_prefix}:*")
      keys.each do |key|
        redis.del(key)
      end
    end
  end

  def log_request(full_path:, user:, status:, duration:, month_key: nil)
    month_key ||= Time.now.strftime('%Y-%m')

    @redis_pool.with do |redis|
      redis.multi do |multi|
        multi.hincrby(UserStats.monitor_key(month_key, user), full_path, 1)
        multi.hincrby(ErrorStats.monitor_key(month_key, full_path), status, 1)
        multi.zadd(RequestStats.monitor_key(month_key, full_path), duration, SecureRandom.uuid)
      end
      # remove_datcv_six_months_back(redis,)
    end
  end

  def global_stats
    @redis_pool.with do |redis|
      user_stats = UserStats.new(redis: redis)
      request_stats = RequestStats.new(redis: redis)
      error_stats = ErrorStats.new(redis: redis)
      {
        total_users_calls: user_stats.total_requests_count,
        total_endpoints_calls: user_stats.endpoint_request_count,
        latest_users_calls: user_stats.latest_requests_count,
        avg_response_times: request_stats.total_avg_response_times,
        total_status_count: error_stats.total_status_count
      }
    end
  end

  def monthly_stats(month = Time.now.strftime('%Y-%m'))
    @redis_pool.with do |redis|
      user_stats = UserStats.new(redis: redis)
      response_stats = RequestStats.new(redis: redis)
      error_stats = ErrorStats.new(redis: redis)
      {
        total_users_calls: user_stats.month_request_count(month),
        total_endpoints_calls: user_stats.month_endpoint_request_count(month),
        avg_response_times: response_stats.month_avg_response_times(month),
        status_count: error_stats.month_status_count(month)
      }
    end
  end

  def memory_stats
    @redis_pool.with do |redis|
      get_memory_stats_redis(redis)
    end
  end

  private

  def remove_data_six_months_back(redis, keys)
    shift_month = (Time.now - 6 * 30 * 24 * 60 * 60).strftime('%Y-%m')
    keys.each do |key|
      redis.del(key.gsub('*', shift_month))
    end
  end

  def get_memory_stats_redis(redis)
    keys_info = {
      monitoring_keys: 0,
      monitoring_memory: 0
    }

    monitoring_patterns = %w[user_requests:* response_times:* errors:*]

    monitoring_patterns.each do |pattern|
      keys = redis.keys("#{@key_prefix}:#{pattern}")
      keys_info[:monitoring_keys] += keys.length

      keys.each do |key|
        memory_usage = begin
                         redis.memory(:usage, key)
                       rescue StandardError
                         nil
                       end
        keys_info[:monitoring_memory] += memory_usage.to_i if memory_usage
      end
    end

    {
      total_keys: keys_info[:monitoring_keys],
      estimated_memory_bytes: keys_info[:monitoring_memory],
      estimated_memory_human: "#{(keys_info[:monitoring_memory].to_f / 1024 / 1024).round(2)}MB"
    }
  end

end