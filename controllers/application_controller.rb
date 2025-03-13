# This is the base class for controllers in the application.
# Code in the before or after blocks will run on every request
require_relative '../helpers/swagger_ui_helper'
require_relative '../helpers/openapi_helper'

class ApplicationController
  include Sinatra::Delegator
  extend Sinatra::Delegator

  # Run before route
  before {
  }

  # Run after route
  after {
  }

  register Sinatra::OpenAPIHelper

  configure do
    set :app_name, 'MOD-API Documentation'
    set :api_version, '1.0.0'
    set :api_description, 'Ontoportal MOD-API documentation'
    set :base_url, LinkedData.settings.rest_url_prefix

    # TODO: add them automatically
    set :api_schemas, {
      artefacts: {
        type: 'object',
        allOf: [
          { '$ref' => '#/components/schemas/page' }
        ],
        properties: {
          collection: {
            type: 'array',
            items: { '$ref' => '#/components/schemas/modSemanticArtefact' }
          }
        }
      },

      distributions: {
        type: 'object',
        allOf: [
          { '$ref' => '#/components/schemas/page' }
        ],
        properties: {
          collection: {
            type: 'array',
            items: { '$ref' => '#/components/schemas/modSemanticArtefactDistribution' }
          }
        }
      },

      page:{
        type: 'object',
        properties: {
          page: { type: 'integer' },
          pageCount: { type: 'integer' },
          totalCount: { type: 'integer' },
          prevPage: { type: 'string', format: 'uri' },
          nextPage: { type: 'string', format: 'uri' },
          links: {
            type: 'object',
            properties: {
              nextPage: { type: 'string', format: 'uri' },
              prevPage: { type: 'string', format: 'uri' }
            }
          }
        }
      },

      modSemanticArtefact: {
        type: 'object',
        properties: {
          '@id': { type: 'string', format: 'uri'},
          '@type': { type: 'string', format: 'uri'},
          links: { 
            type: 'object',
            properties: {
              link: { type: 'string', format: 'uri' },
              '@context': { type: 'array', items: {type: 'string'} }
            }
          },
          '@context': {
            type: 'object',
            properties: {
              property: { type: 'string', format: 'uri' },
            }
          }
        }
      },

      modSemanticArtefactDistribution: {
        type: 'object',
        properties: {
          '@id': { type: 'string', format: 'uri'},
          '@type': { type: 'string',  const: 'https://w3id.org/mod#SemanticArtefactDistribution' },
          links: { 
            type: 'object',
            properties: {
              link: { type: 'string', format: 'uri' },
              '@context': { type: 'array', items: {type: 'string'} }
            }
          },
          '@context': {
            type: 'object',
            properties: {
              property: { type: 'string', format: 'uri' },
            }
          }
        }
      },

      error: {
        type: 'object',
        properties: {
          errors: { 
            type: 'array',
            items: {
              type: 'string'
            }
          },
          status: { type: 'integer' }
        }
      }


    }
  end

end
