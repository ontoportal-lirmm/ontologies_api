require 'multi_json'

module Admin

  class LoggingController < ApplicationController

    namespace "/admin" do
      before {
        if LinkedData.settings.enable_security && (!env["REMOTE_USER"] || !env["REMOTE_USER"].admin?)
          error 403, "Access denied"
        end
      }

      get '/latest_query_logs' do
        logs = Goo.logger.get_logs
        logs = logs.map { |log| MultiJson.load(log) }
        reply logs
      end

    end
  end
end
