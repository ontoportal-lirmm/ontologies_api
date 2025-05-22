class RecordsController < ApplicationController
  namespace "/mod-api" do
    namespace "/records" do
      doc('Record', "Get information about all semantic artefact catalog records") do
        default_params(display: true, pagination: true)
        response(200, "OK", content('$ref' => '#/components/schemas/hydraPage'))
      end
      get do
        check_last_modified_collection(LinkedData::Models::SemanticArtefactCatalogRecord)
        attributes, page, pagesize= settings_params(LinkedData::Models::SemanticArtefactCatalogRecord).first(3)
        pagesize ||= 20
        attributes = LinkedData::Models::SemanticArtefactCatalogRecord.goo_attrs_to_load([]) if includes_param.first == :all
        records = LinkedData::Models::SemanticArtefactCatalogRecord.all(attributes, page, pagesize)
        reply records
      end

      doc('Record', "Get information about a semantic artefact catalog record") do
        path_parameter('artefactID', type: 'string', description: 'The acronym of the artefact', default: "STY")
        default_params(display: true)
        default_responses(success: true, not_found: true)
      end
      get "/:artefactID" do
        record = LinkedData::Models::SemanticArtefactCatalogRecord.find(params["artefactID"])
        error 404, "You must provide a valid `artefactID` to retrieve ats record" if record.nil?
        check_last_modified(record)
        record.bring(*LinkedData::Models::SemanticArtefactCatalogRecord.goo_attrs_to_load(includes_param))
        reply record
      end
    end
  end
end
