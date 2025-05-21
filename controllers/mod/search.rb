class ArtefactsSearchController < ApplicationController
  namespace "/mod-api" do
    namespace "/search" do
      
      doc('Search', 'Search content/metadata of artefacts') do
        default_params(display: true, pagination: true, query: true)
        response(200, "OK", content('$ref' => '#/components/schemas/hydraPage'))
      end
      get do
        result = process_search
        reply hydra_page_object(result.to_a, result.aggregate)
      end

      doc('Search', 'Search content of artefacts') do
        default_params(display: true, pagination: true, query: true)
        response(200, "OK", content('$ref' => '#/components/schemas/hydraPage'))
      end
      get '/content' do
        result = process_search
        reply hydra_page_object(result.to_a, result.aggregate)
      end

      doc('Search', 'Search metadata of artefacts') do
        default_params(display: true, pagination: true, query: true)
        response(200, "OK", content('$ref' => '#/components/schemas/hydraPage'))
      end
      get '/metadata' do
        query = get_query(params)
        options = get_ontology_metadata_search_options(params)
        page, page_size = page_params

        resp = search(Ontology, query, options)

        result = {}
        acronyms_ids = {}
        resp.each do |doc|
          id = doc["submissionId_i"]
          acronym = doc["ontology_acronym_text"] || doc["ontology_t"]&.split('/')&.last
          next if acronym.blank?

          old_id = acronyms_ids[acronym].to_i rescue 0
          already_found = (old_id && id && (id <= old_id))

          next if already_found

          not_restricted = (doc["ontology_viewingRestriction_t"]&.eql?('public') || current_user&.admin?)
          user_not_restricted = not_restricted ||
            Array(doc["ontology_viewingRestriction_txt"]).any? {|u| u.split(' ').last == current_user&.username} ||
            Array(doc["ontology_acl_txt"]).any? {|u| u.split(' ').last == current_user&.username}

          user_restricted = !user_not_restricted
          next if user_restricted

          acronyms_ids[acronym] = id
          result[acronym] = LinkedData::Models::SemanticArtefact.read_only(id: "#{LinkedData.settings.id_url_prefix}artefacts/#{acronym}", acronym: acronym, description: doc['description_text'], title: doc['ontology_name_text'])
        end

        reply hydra_page_object(result.values, result.length)
      end
    end
  end
end