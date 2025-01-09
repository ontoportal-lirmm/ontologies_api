class ArtefactsController < ApplicationController

    namespace "/artefacts" do
        # Get all Semantic Artefacts
        get do
            artefacts = nil
            check_last_modified_collection(LinkedData::Models::SemanticArtefact)
            options = {
                allow_views: params['also_include_views'] ||= false,
                includes: LinkedData::Models::SemanticArtefact.goo_attrs_to_load([])
            }
            artefacts = LinkedData::Models::SemanticArtefact.all_artefacts(options)
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

    end

end