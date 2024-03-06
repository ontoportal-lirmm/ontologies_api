require 'sinatra/base'

module Sinatra
  module Helpers
    module UploadOntologyHelper

      def create_ontology_from_file(format = nil )
        LinkedData::SampleData::Ontology.create_ontologies_and_submissions({
                                                                             process_submission: false,
                                                                             acronym: 'INRAETHES',
                                                                             name: 'INRAETHES',
                                                                             ont_count: 1,
                                                                             submission_count: 1,
                                                                             ontology_format: format || 'OWL'
                                                                           })
        ont = Ontology.find('INRAETHES-0').include(:acronym).first
        sub = ont.latest_submission(status: :any)
        add_file_to_submission(ont, sub)
        [ont, sub]
      end

      def perform_step(step, start_msg, end_msg, error_msg, &block)
        broadcast_update(step, 1, start_msg)
        outputs = nil

        time = Benchmark.realtime do
          begin
            outputs = block.call
          rescue StandardError => e
            outputs = nil
          end
        end

        if outputs
          broadcast_update(step, 2, end_msg, time)
        else
          broadcast_update(step, 0, error_msg, time)
        end
        outputs
      end

      def broadcast_update(id, status, message, time = nil)
        msg = {
          id: id,
          status: status,
          time: time,
          message: message
        }
        upload_ontology_ws_broadcast(msg.to_json)
      end

      def upload_ontology_ws_subscribe(channel_id = "",env = request.env)
        websockets.subscribe("UploadOntologyController:#{channel_id}", env)
      end

      def upload_ontology_ws_unsubscribe(channel_id = "")
        websockets.unsubscribe("UploadOntologyController:#{channel_id}")
      end

      def upload_ontology_ws_broadcast(channel_id = "", message)
        websockets.broadcast("UploadOntologyController:#{channel_id}", message)
      end

    end
  end
end

helpers Sinatra::Helpers::UploadOntologyHelper