require 'json'
require 'sinatra/base'


module Sinatra
  module SwaggerUI
    def generate_openapi_json
      {
        openapi: '3.0.0',
        info: {
          title: settings.app_name || 'MOD-API Documentation',
          version: settings.api_version || '1.0.0',
          description: settings.api_description || 'MOD-API Documentation'
        },
        servers: [
          {
            url: settings.base_url || '/'
          }
        ],
        tags: [
          { name: 'Artefact', description: 'Get information about semantic artefact(s) (ontologies, terminologies, taxonomies, thesauri, vocabularies, metadata schemas and semantic standards) or their resources.' },
          { name: 'Catalog', description: 'Get information about the semantic artefact catalogue.' },
          { name: 'Record', description: 'Get semantic artefact catalogue records' },
          { name: 'Search', description: 'Search the metadata and catalogue content.' }
        ],
        paths: generate_paths,
        components: {
          schemas: settings.respond_to?(:api_schemas) ? settings.api_schemas : {}
        }
      }
    end

    def generate_paths
      paths = {}
      api_docs = settings.instance_variable_get(:@api_docs)
      sorted_paths = api_docs.keys.sort_by do |path|
        path.is_a?(Mustermann::Sinatra) ? path.to_s : path
      end

      sorted_paths.each do |path|
        paths[path] = api_docs[path].transform_keys(&:to_s)
      end
      paths
    end
  end
end

helpers Sinatra::SwaggerUI
