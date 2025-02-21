require 'json'
require 'sinatra/base'


module Sinatra
  module SwaggerUI
    def generate_openapi_json
      {
        openapi: '3.0.0',
        info: {
          title: settings.app_name || 'API Documentation',
          version: settings.api_version || '1.0.0',
          description: settings.api_description || 'API Documentation'
        },
        servers: [
          {
            url: settings.base_url || '/',
            description: 'API Server'
          }
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
      api_docs.each do |path, methods|
        paths[path] = methods.transform_keys(&:to_s)
      end
      paths
    end
  end
end

helpers Sinatra::SwaggerUI
