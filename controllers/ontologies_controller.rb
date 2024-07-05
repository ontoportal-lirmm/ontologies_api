class OntologiesController < ApplicationController

  namespace "/ontologies" do

    ##
    # Display all ontologies
    get do
      onts = nil
      check_last_modified_collection(Ontology)
      allow_views = params['also_include_views'] ||= false
      if allow_views
        onts = Ontology.where.include(Ontology.goo_attrs_to_load(includes_param)).to_a
      else
        onts = Ontology.where.filter(Goo::Filter.new(:viewOf).unbound).include(Ontology.goo_attrs_to_load(includes_param)).to_a
      end
      reply onts
    end

    ##
    # Display the most recent submission of the ontology
    get '/:acronym' do
      ont = Ontology.find(params["acronym"]).first
      error 404, "You must provide a valid `acronym` to retrieve an ontology" if ont.nil?
      check_last_modified(ont)
      ont.bring(*Ontology.goo_attrs_to_load(includes_param))
      reply ont
    end

    ##
    # Ontology latest submission
    get "/:acronym/latest_submission" do
      ont = Ontology.find(params["acronym"]).first
      error 404, "You must provide a valid `acronym` to retrieve an ontology" if ont.nil?
      include_status = params["include_status"]
      ont.bring(:acronym, :submissions)
      if include_status
        latest = ont.latest_submission(status: include_status.to_sym)
      else
        latest = ont.latest_submission(status: :any)
      end

      if latest
        check_last_modified(latest)
        latest.bring(*submission_include_params)
      end

      reply(latest || {})
    end

    # Ontology latest submission datacite metadata as Json
    get "/:acronym/latest_submission/datacite_metadata_json" do
      params["display"] = 'all'
      latest = find_latest_submission
      latest.bring(*OntologySubmission.goo_attrs_to_load(includes_param)) if latest
      if latest
        to_data_cite_facet(latest).to_json
      else
        reply {}
      end
    end

    get "/:acronym/latest_submission/ecoportal_metadata_json" do
      params["display"] = 'all'
      latest = find_latest_submission
      latest.bring(*OntologySubmission.goo_attrs_to_load(includes_param)) if latest
      if latest
        to_eco_portal_facet(latest).to_json
      else
        reply {}
      end
    end

    ##
    # Update latest submission of an ontology
    REQUIRES_REPROCESS = ["prefLabelProperty", "definitionProperty", "synonymProperty", "authorProperty", "classType", "hierarchyProperty", "obsoleteProperty", "obsoleteParent"]
    patch '/:acronym/latest_submission' do
      ont = Ontology.find(params["acronym"]).first
      error 422, "You must provide an existing `acronym` to patch" if ont.nil?

      submission = ont.latest_submission(status: :any)

      submission.bring(*OntologySubmission.attributes)
      populate_from_params(submission, params)
      add_file_to_submission(ont, submission)

      if submission.valid?
        submission.save
        if (params.keys & REQUIRES_REPROCESS).length > 0 || request_has_file?
          cron = NcboCron::Models::OntologySubmissionParser.new
          cron.queue_submission(submission, { all: true })
        end
      else
        error 422, submission.errors
      end

      halt 204
    end

    ##
    # Create an ontology
    post do
      create_ontology_with_params
    end

    ##
    # Create an ontology with constructed URL
    put '/:acronym' do
      create_ontology_with_params
    end

    ##
    # Update an ontology
    patch '/:acronym' do
      ont = Ontology.find(params["acronym"]).include(Ontology.attributes).first
      error 422, "You must provide an existing `acronym` to patch" if ont.nil?

      populate_from_params(ont, params)
      if ont.valid?
        ont.save
      else
        error 422, ont.errors
      end

      halt 204
    end

    ##
    # Delete an ontology and all its versions
    delete '/:acronym' do
      ont = Ontology.find(params["acronym"]).first
      error 422, "You must provide an existing `acronym` to delete" if ont.nil?
      ont.delete
      # update ontologies report file, if exists
      NcboCron::Models::OntologiesReport.new.delete_ontologies_from_report([params["acronym"]])
      halt 204
    end

    ##
    # Download the latest submission for an ontology
    get '/:acronym/download' do
      acronym = params["acronym"]
      ont = Ontology.find(acronym).include(Ontology.goo_attrs_to_load).first
      ont.bring(:viewingRestriction) if ont.bring?(:viewingRestriction)
      error 422, "You must provide an existing `acronym` to download" if ont.nil?
      check_access(ont)
      restricted_download = LinkedData::OntologiesAPI.settings.restrict_download.include?(acronym)
      error 403, "License restrictions on download for #{acronym}" if restricted_download && !current_user.admin?
      error 403, "Ontology #{acronym} is not accessible to your user" if ont.restricted? && !ont.accessible?(current_user)
      latest_submission = ont.latest_submission(status: :rdf) # Should resolve to latest successfully loaded submission
      error 404, "There is no latest submission loaded for download" if latest_submission.nil?
      latest_submission.bring(:uploadFilePath)

      download_format = params["download_format"].to_s.downcase
      allowed_formats = ["csv", "rdf"]
      if download_format.empty?
        file_path = latest_submission.uploadFilePath
      elsif ([download_format] - allowed_formats).length > 0
        error 400, "Invalid download format: #{download_format}."
      elsif download_format.eql?("csv")
        latest_submission.bring(ontology: [:acronym])
        file_path = latest_submission.csv_path
      elsif download_format.eql?("rdf")
        file_path = latest_submission.rdf_path
      end

      if File.readable? file_path
        send_file file_path, :filename => File.basename(file_path)
      else
        error 500, "Cannot read latest submission upload file: #{file_path}"
      end
    end

    private
    def find_latest_submission
      ont = Ontology.find(params["acronym"]).first
      error 404, "You must provide a valid `acronym` to retrieve an ontology" if ont.nil?
      include_status = params["include_status"]
      ont.bring(:acronym, :submissions)
      if include_status
        latest = ont.latest_submission(status: include_status.to_sym)
      else
        latest = ont.latest_submission(status: :any)
      end
      check_last_modified(latest) if latest
      latest
    end

    def create_ontology_with_params
      ont = create_ontology
      if ont.valid?
        reply 201, ont
      else
        error 422, ont.errors
      end
    end
  end

  namespace "/ontologies_full" do
    ##
    # Display all ontologies with submissions and metrics
    get do
      resp = []
      onts = nil
      allow_views = params['also_include_views'] ||= false

      if allow_views
        onts = Ontology.where.include(Ontology.goo_attrs_to_load(includes_param)).to_a
      else
        onts = Ontology.where.filter(Goo::Filter.new(:viewOf).unbound).include(Ontology.goo_attrs_to_load(includes_param)).to_a
      end
      options = { also_include_views: allow_views, status: (params["include_status"] || "ANY") }
      subs = retrieve_latest_submissions(options)
      metrics_include = LinkedData::Models::Metric.goo_attrs_to_load(includes_param)
      LinkedData::Models::OntologySubmission.where.models(subs.values).include(metrics: metrics_include).all

      onts.each do |ont|
        sub = subs[ont.acronym]
        sub.ontology = nil if sub
        metrics = nil

        begin
          metrics = sub.nil? ? nil : sub.metrics
        rescue
          metrics = nil
        end

        resp << { ontology: ont, latest_submission: subs[ont.acronym], metrics: metrics }
      end

      reply resp
    end
  end
end
