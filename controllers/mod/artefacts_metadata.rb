class ArtefactsMetadataController < ApplicationController
  namespace "/artefacts" do
    # Get all Semantic Artefacts
    get do
      check_last_modified_collection(LinkedData::Models::SemanticArtefact)
      attributes, page, pagesize = settings_params(LinkedData::Models::SemanticArtefact).first(3)
      pagesize ||= 20
      attributes = LinkedData::Models::SemanticArtefact.goo_attrs_to_load([]) if includes_param.first == :all
      artefacts = LinkedData::Models::SemanticArtefact.all_artefacts(attributes, page, pagesize)
      reply artefacts
    end

    # Get one semantic artefact by ID
    get "/:artefactID" do
      artefact = find_artefact(params["artefactID"])      
      error 404, "You must provide a valid `artefactID` to retrieve an artefact" if artefact.nil?
      check_last_modified(artefact)
      artefact.bring(*LinkedData::Models::SemanticArtefact.goo_attrs_to_load(includes_param))
      reply artefact
    end

    # Get artefact catalog record by ID
    get "/:artefactID/record" do
      record = LinkedData::Models::SemanticArtefactCatalogRecord.find(params["artefactID"])
      error 404, "You must provide a valid `artefactID` to retrieve ats record" if record.nil?
      check_last_modified(record)
      record.bring(*LinkedData::Models::SemanticArtefactCatalogRecord.goo_attrs_to_load(includes_param))
      reply record
    end

    # Display latest distribution of an artefact
    get "/:artefactID/distributions/latest" do
      artefact = find_artefact(params["artefactID"])
      include_status = params["include_status"]&.to_sym || :any
      latest_distribution = artefact.latest_distribution(status: include_status)

      if latest_distribution
        check_last_modified(latest_distribution)
        latest_distribution.bring(*LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load(includes_param))
      end
      reply latest_distribution
    end

    # Display a distribution by ID
    get '/:artefactID/distributions/:distributionID' do
      artefact = find_artefact(params["artefactID"])
      check_last_modified_segment(LinkedData::Models::SemanticArtefactDistribution, [params["artefactID"]])
      artefact_distribution = artefact.distribution(params["distributionID"])
      error 404, "Distribution with ID #{params['distributionID']} not found" if artefact_distribution.nil?
      artefact_distribution.bring(*LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load(includes_param))
      reply artefact_distribution
    end

    # Display all distributions of an artefact
    get '/:artefactID/distributions' do
      artefact = find_artefact(params["artefactID"])
      check_last_modified_segment(LinkedData::Models::SemanticArtefactDistribution, [params["artefactID"]])
      options = { status: (params["include_status"] || "ANY"), includes: LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load([]) }
      distros = artefact.all_distributions(options)
      reply distros.sort { |a, b| b.distributionId.to_i <=> a.distributionId.to_i }
    end
    
  end

  namespace "/records" do
    # Get all Semantic Artefact Catalog Records
    get do
      check_last_modified_collection(LinkedData::Models::SemanticArtefactCatalogRecord)
      attributes, page, pagesize= settings_params(LinkedData::Models::SemanticArtefactCatalogRecord).first(3)
      pagesize ||= 20
      attributes = LinkedData::Models::SemanticArtefactCatalogRecord.goo_attrs_to_load([]) if includes_param.first == :all
      records = LinkedData::Models::SemanticArtefactCatalogRecord.all(attributes, page, pagesize)
      reply records
    end

    # Get a specific record by artefact ID
    get "/:artefactID" do
      record = LinkedData::Models::SemanticArtefactCatalogRecord.find(params["artefactID"])
      error 404, "You must provide a valid `artefactID` to retrieve ats record" if record.nil?
      check_last_modified(record)
      record.bring(*LinkedData::Models::SemanticArtefactCatalogRecord.goo_attrs_to_load(includes_param))
      reply record
    end
  
  end
end
