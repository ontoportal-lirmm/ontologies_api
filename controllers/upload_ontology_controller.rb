# app.rb
require 'sinatra/base'
require 'faye/websocket'
require 'thread'

class UploadOntologyController < ApplicationController
  require 'logger'
  require 'observer'

  class ObservableLogger
    include Observable

    def initialize(logfile)
      @logger = Logger.new(logfile)
    end

    def log(severity, message)
      @logger.send(severity, message)
      changed
      notify_observers(severity, message)
    end

    def flush
      @logger.flush
    end

    def info(message)
      log(:info, message)
    end

    def warn(message)
      log(:warn, message)
    end

    def error(message)
      log(:error, message)
    end

    def fatal(message)
      log(:fatal, message)
    end
  end

  get '/ontologies/upload/ws' do
    upload_ontology_ws_subscribe
  end

  post '/ontologies/upload' do
    ont, sub = perform_step(:ontology_creation,
                            "Start creating an ontology",
                            "Ontology  created",
                            "Ontology creation failed"
    ) do
      create_ontology_from_file('SKOS')
    end

    Thread.new do
      # actions = {
      #   :process_rdf => true,
      #   :generate_labels => true,
      #   :extract_metadata => true,
      #   :index_search => true,
      #   :index_properties => true,
      #   :run_metrics => true,
      #   :process_annotator => true,
      #   :diff => true,
      #   :remote_pull => false
      # }
      break if ont.nil?

      begin

        steps = {
          :process_rdf => {
            label: 'Parse and  save in RDF Store',
            options: { process_rdf: true, extract_metadata: false, generate_labels: true }
          },
          :extract_metadata => {
            label: "Extract metadata",
            options: { extract_metadata: true }
          },
          # :index_search => {
          #   label: "Indexing terms",
          #   options: { index_search: true },
          # },
          :index_properties => {
            label: "Indexing properties",
            options: { index_properties: true },
          },
          :run_metrics => {
            label: "Computing metrics",
            options: { run_metrics: true }
          }
        }

        steps.each do |step, options|
          perform_step(step,
                       "Start #{options[:label]}",
                       "#{options[:label]} ended successfully",
                       "#{options[:label]} failed") do
            logger = ObservableLogger.new('app.log')

            observer = lambda do |severity, message|
              broadcast_update(step, 1, message)
            end

            logger.add_observer(observer, :call)
            sub.process_submission(logger, options[:options])
          end
          sub = LinkedData::Models::OntologySubmission.find(sub.id).first
          sub.bring_remaining
        end

        if sub.ready?
          broadcast_update(:result, 2, "#{ont.acronym} parsed successfully")
          broadcast_update(:result, 2, sub.metrics.to_hash.to_json)
        end
      rescue StandardError => e
        broadcast_update(:result, 0, "#{ont.acronym} processing error: #{e.message}")
      ensure
        ont.delete
        upload_ontology_ws_unsubscribe
      end
    end
    status 200
  end

end


