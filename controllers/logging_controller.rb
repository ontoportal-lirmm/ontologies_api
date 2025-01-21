require 'multi_json'

module Admin

  class LoggingController < ApplicationController

    namespace "/admin" do
      before {
        if LinkedData.settings.enable_security && (!env["REMOTE_USER"] || !env["REMOTE_USER"].admin?)
          error 403, "Access denied"
        end
      }

      get '/latest_day_query_logs' do
        logs = Goo.logger.get_logs
        reply 200, paginate_logs(logs)
      end

      get '/last_n_s_query_logs' do
        sec = params[:seconds] || 10
        logs = Goo.logger.queries_last_n_seconds(sec.to_i)
        reply 200, paginate_logs(logs)
      end

      get '/user_query_count' do
        counts = Goo.logger.users_query_count
        reply 200, counts
      end

      def paginate_logs(logs)
        page, size = page_params
        start = (page - 1) * size
        page_end = [start + size - 1, logs.size].min
        page_logs = logs[start..page_end] || []
        page_object(page_logs, logs.size)
      end

    end
  end
end
