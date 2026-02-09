require 'sidekiq'
module Jobs
  class Base
    include Sidekiq::Job
    sidekiq_options queue: 'default'
  
    # Base class for non-retryable errors
    class HandledException < StandardError; end
    class NonRetryableError < HandledException; end
    
    sidekiq_retry_in do |count, exception|
      case exception
      when NonRetryableError
        :kill
      else
        nil
      end
    end
  end 
end
