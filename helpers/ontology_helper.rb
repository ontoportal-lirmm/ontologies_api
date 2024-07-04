require 'sinatra/base'
require 'json'
require_relative 'concerns/ecoportal_metadata_exporter'

module Sinatra
  module Helpers
    module OntologyHelper
      include Sinatra::Concerns::EcoPortalMetadataExporter

      def create_ontology
        params ||= @params

        # acronym must be well formed
        params['acronym'] = params['acronym'].upcase # coerce new ontologies to upper case

        # ontology acronym must be unique
        ont = Ontology.find(params['acronym']).first
        if ont.nil?
          ont = instance_from_params(Ontology, params)
        else
          error_msg = <<-ERR
        Ontology already exists, see #{ont.id}
        To add a new submission, POST to: /ontologies/#{params['acronym']}/submission.
        To modify the resource, use PATCH.
        ERR
          error 409, error_msg
        end

        # ontology name must be unique
        ont_names = Ontology.where.include(:name).to_a.map { |o| o.name }
        if ont_names.include?(ont.name)
          error 409, "Ontology name is already in use by another ontology."
        end

        if ont.valid?
          ont.save
          # Send an email to the administrator to warn him about the newly created ontology
          begin
            if !LinkedData.settings.admin_emails.nil? && !LinkedData.settings.admin_emails.empty?
              LinkedData::Utils::Notifications.new_ontology(ont)
            end
          rescue Exception => e
          end
        end
        ont
      end

      ##
      # Create a new OntologySubmission object based on the request data
      def create_submission(ont)
        params = @params
        submission_id = ont.next_submission_id

        # VocBench adapter
        params = old_eco_portal_adapter(params, ont)

        # Create OntologySubmission
        ont_submission = instance_from_params(OntologySubmission, params)
        ont_submission.ontology = ont
        ont_submission.submissionId = submission_id

        # Get file info
        add_file_to_submission(ont, ont_submission)

        # Add new format if it doesn't exist
        if ont_submission.hasOntologyLanguage.nil?
          error 422, "You must specify the ontology format using the `hasOntologyLanguage` parameter" if params["hasOntologyLanguage"].nil? || params["hasOntologyLanguage"].empty?
          ont_submission.hasOntologyLanguage = OntologyFormat.find(params["hasOntologyLanguage"]).first
        end


        if ont_submission.valid?
          ont_submission.save
          cron = NcboCron::Models::OntologySubmissionParser.new
          cron.queue_submission(ont_submission, {all: true, params: params})
        else
          error 400, ont_submission.errors
        end

        ont_submission
      end


      ##
      # Add a file to the submission if a file exists in the params
      def add_file_to_submission(ont, submission)
        filename, tmpfile = file_from_request
        if tmpfile
          if filename.nil?
            error 400, "Failure to resolve ontology filename from upload file."
          end
          # Copy tmpfile to appropriate location
          ont.bring(:acronym) if ont.bring?(:acronym)
          # Ensure the ontology acronym is available
          if ont.acronym.nil?
            error 500, "Failure to resolve ontology acronym"
          end
          file_location = OntologySubmission.copy_file_repository(ont.acronym, submission.submissionId, tmpfile, filename)
          submission.uploadFilePath = file_location
        end
        return filename, tmpfile
      end
    end
  end
end

helpers Sinatra::Helpers::OntologyHelper
