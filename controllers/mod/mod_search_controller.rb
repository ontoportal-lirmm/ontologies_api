class ModSearchController < ApplicationController
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
        hydra_page_result = search_metadata
        reply hydra_page_result
      end
    end
  end
end