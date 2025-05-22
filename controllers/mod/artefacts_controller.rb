class ArtefactsController < ApplicationController
  namespace "/mod-api" do
    namespace "/artefacts" do

      doc('Artefact', 'Get information about all semantic artefacts') do
        default_params(display: true, pagination: true)
        response(200, "OK", content('$ref' => '#/components/schemas/hydraPage'))
      end
      get do
        check_last_modified_collection(LinkedData::Models::SemanticArtefact)
        attributes, page, pagesize = settings_params(LinkedData::Models::SemanticArtefact).first(3)
        pagesize ||= 20
        attributes = LinkedData::Models::SemanticArtefact.goo_attrs_to_load([]) if includes_param.first == :all
        artefacts = LinkedData::Models::SemanticArtefact.all_artefacts(attributes, page, pagesize)
        reply artefacts
      end

      doc('Artefact', 'Get information about a semantic artefact') do
        path_parameter('artefactID', type: 'string', description: 'The acronym of the artefact', default: "STY")
        default_params(display: true)
        default_responses(success: true, not_found: true)
      end
      get "/:artefactID" do
        artefact = find_artefact(params["artefactID"])
        error 404, "You must provide a valid `artefactID` to retrieve an artefact" if artefact.nil?
        check_last_modified(artefact)
        artefact.bring(*LinkedData::Models::SemanticArtefact.goo_attrs_to_load(includes_param))
        reply artefact
      end

      doc('Artefact', "Get information about a semantic artefact's latest distribution") do
        path_parameter('artefactID', type: 'string', description: 'The acronym of the artefact', default: "STY")
        default_params(display: true)
        default_responses(success: true)
      end
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

      doc('Artefact', "Get information about a semantic artefact's distribution") do
        path_parameter('artefactID', type: 'string', description: 'The acronym of the artefact', default: "STY")
        path_parameter('distributionID', type: 'number', description: 'The id of the distribution', default: 5)
        default_params(display: true)
        default_responses(success: true, not_found: true)
      end
      get '/:artefactID/distributions/:distributionID' do
        artefact = find_artefact(params["artefactID"])
        check_last_modified_segment(LinkedData::Models::SemanticArtefactDistribution, [params["artefactID"]])
        artefact_distribution = artefact.distribution(params["distributionID"])
        error 404, "Distribution with ID #{params['distributionID']} not found" if artefact_distribution.nil?
        artefact_distribution.bring(*LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load(includes_param))
        reply artefact_distribution
      end

      doc('Artefact', "Get information about a semantic artefact's distributions") do
        path_parameter('artefactID', type: 'string', description: 'The acronym of the artefact', default: "STY")
        default_params(display: true, pagination: true)
        response(200, "OK", content('$ref' => '#/components/schemas/hydraPage'))
        default_responses(not_found: true)
      end
      get '/:artefactID/distributions' do
        artefact = find_artefact(params["artefactID"])
        check_last_modified_segment(LinkedData::Models::SemanticArtefactDistribution, [params["artefactID"]])
        attributes, page, pagesize= settings_params(LinkedData::Models::SemanticArtefactDistribution).first(3)
        attributes = LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load([]) if includes_param.first == :all
        distros = artefact.all_distributions(attributes, page, pagesize)
        reply distros
      end

      doc('Record', "Get information about a semantic artefact catalog record") do
        path_parameter('artefactID', type: 'string', description: 'The acronym of the artefact', default: "STY")
        default_params(display: true)
        default_responses(success: true, not_found: true)
      end
      get "/:artefactID/record" do
        record = LinkedData::Models::SemanticArtefactCatalogRecord.find(params["artefactID"])
        error 404, "You must provide a valid `artefactID` to retrieve ats record" if record.nil?
        check_last_modified(record)
        record.bring(*LinkedData::Models::SemanticArtefactCatalogRecord.goo_attrs_to_load(includes_param))
        reply record
      end
    end
  end
end
