require 'sinatra/base'

module Sinatra
  module Helpers
    module AdminJobsHelper

      def redis_cron
        Redis.new(host: NcboCron.settings.redis_host, port: NcboCron.settings.redis_port, timeout: 30)
      end

      def cron_daemon_options
        cron_settings_json = redis_cron.get "cron:daemon:options"
        error 500, "Unable to get CRON daemon options from Redis" if cron_settings_json.nil?
        ::JSON.parse(cron_settings_json, symbolize_names: true)
      end

      def scheduled_jobs_map
        cron_options = cron_daemon_options

        {
          parse: {
            title: "parse semantic resources",
            enabled: cron_options[:enable_processing] || false,
            scheduler_type: "every",
            schedule: "5m" # this is hardcoded in the scheduler class
          },
          pull: {
            title: "pull remote semantic resources",
            enabled: cron_options[:enable_pull] || false,
            scheduler_type: "cron",
            schedule: cron_options[:pull_schedule]
          },
          flush: {
            title: "flush classes",
            enabled: cron_options[:enable_flush] || false,
            scheduler_type: "cron",
            schedule: cron_options[:cron_flush]
          },
          warmq: {
            title: "warm up queries",
            enabled: cron_options[:enable_warmq] || false,
            scheduler_type: "cron",
            schedule: cron_options[:cron_warmq]
          },
          mapping_counts: {
            title: "mapping counts generation",
            enabled: cron_options[:enable_mapping_counts] || false,
            scheduler_type: "cron",
            schedule: cron_options[:cron_mapping_counts]
          },
          ontology_analytics: {
            title: "semantic resource analytics",
            enabled: cron_options[:enable_ontology_analytics] || false,
            scheduler_type: "cron",
            schedule: cron_options[:cron_ontology_analytics]
          },
          ontologies_report: {
            title: "semantic resources report",
            enabled: cron_options[:enable_ontologies_report] || false,
            scheduler_type: "cron",
            schedule: cron_options[:cron_ontologies_report]
          },
          index_synchronizer: {
            title: "index synchronization",
            enabled: cron_options[:enable_index_synchronizer] || false,
            scheduler_type: "cron",
            schedule: cron_options[:cron_index_synchronizer]
          },
          spam_deletion: {
            title: "spam deletion",
            enabled: cron_options[:enable_spam_deletion] || false,
            scheduler_type: "cron",
            schedule: cron_options[:cron_spam_deletion]
          },
          obofoundry_sync: {
            title: "OBO Foundry synchronization",
            enabled: cron_options[:enable_obofoundry_sync] || false,
            scheduler_type: "cron",
            schedule: cron_options[:cron_obofoundry_sync]
          }
        }
      end

      def stream_file(filename)
        if !File.exist? filename
          stream { |out| out << "" }
        else
          content_type "text/plain"
          stream do |out|
            File.open(filename, mode = "r") do |f|
              loop do
                chunk = f.read 4096
                if chunk.nil?
                  break
                else
                  out << chunk
                end
              end
            end
          end
        end
      end
    end
  end
end

helpers Sinatra::Helpers::AdminJobsHelper
