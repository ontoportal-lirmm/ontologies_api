class ArtefactsController < ApplicationController

    namespace "/artefacts" do
        # Get all Semantic Artefacts
        get do
            check_last_modified_collection(LinkedData::Models::SemanticArtefact)
            attributes, page, pagesize, _, _ = settings_params(LinkedData::Models::SemanticArtefact)
            pagesize = 20 if params["pagesize"].nil?
            artefacts = LinkedData::Models::SemanticArtefact.all_artefacts(attributes, page, pagesize)
            reply artefacts
        end

        # Get one semantic artefact by ID
        get "/:artefactID" do
            artefact = LinkedData::Models::SemanticArtefact.find(params["artefactID"])
            error 404, "You must provide a valid `artefactID` to retrieve an artefact" if artefact.nil?
            check_last_modified(artefact)
            artefact.bring(*LinkedData::Models::SemanticArtefact.goo_attrs_to_load(includes_param))
            reply artefact
        end

        # Display latest distribution
        get "/:artefactID/distributions/latest" do
            artefact = LinkedData::Models::SemanticArtefact.find(params["artefactID"])
            error 404, "You must provide a valid artefactID to retrieve an artefact" if artefact.nil?
            include_status = params["include_status"] && !params["include_status"].empty? ? params["include_status"].to_sym : :any
            latest_distribution = artefact.latest_distribution(status: include_status)

            if latest_distribution
                check_last_modified(latest_distribution)
                latest_distribution.bring(*LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load(includes_param))
            end
            reply latest_distribution
        end

        # Display a distribution
        get '/:artefactID/distributions/:distributionID' do
            artefact = LinkedData::Models::SemanticArtefact.find(params["artefactID"])
            error 422, "Semantic Artefact #{params["artefactID"]} does not exist" unless artefact
            check_last_modified_segment(LinkedData::Models::SemanticArtefactDistribution, [params["artefactID"]])
            artefact_distribution = artefact.distribution(params["distributionID"])
            error 404, "Distribuution with #{params['distributionID']} not found" if artefact_distribution.nil?
            artefact_distribution.bring(*LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load(includes_param))
            reply artefact_distribution
        end

        # Display a distribution
        get '/:artefactID/distributions' do
            artefact = LinkedData::Models::SemanticArtefact.find(params["artefactID"])
            error 404, "Semantic Artefact #{params["acronym"]} does not exist" unless artefact
            check_last_modified_segment(LinkedData::Models::SemanticArtefactDistribution, [params["artefactID"]])
            options = {
                status: (params["include_status"] || "ANY"),
                includes: LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load([])
            }
            distros = artefact.all_distributions(options)
            reply distros.sort {|a,b| b.distributionId.to_i <=> a.distributionId.to_i }
        end

    end

end