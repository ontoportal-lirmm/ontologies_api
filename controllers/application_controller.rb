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

    set :api_schemas, {
      hydraPage: {
        type: 'object',
        required: ['@context', '@id', '@type', 'totalItems', 'itemsPerPage', 'member', 'view'],
        properties: {
          '@context': {
            type: 'object'
          },
          '@id': { type: 'string', format: 'uri' },
          '@type': { type: 'string', enum: ['hydra:Collection'] },
          'totalItems': { type: 'integer' },
          'itemsPerPage': { type: 'integer' },
          'view': {
            type: 'object',
            required: ['@id', '@type'],
            properties: {
              '@id': { type: 'string', format: 'uri' },
              '@type': { type: 'string', enum: ['hydra:PartialCollectionView'] },
              'firstPage': { type: 'string', format: 'uri' },
              'previousPage': { type: 'string', format: 'uri' },
              'nextPage': { type: 'string', format: 'uri' },
              'lastPage': { type: 'string', format: 'uri' }
            }
          },
          'member': {
            type: 'array',
            items: { type: 'object' }
          }
        }
      },
        modSemanticArtefact: {
        type: 'object',
        properties: {
          '@id': { type: 'string', format: 'uri'},
          '@type': { type: 'string',  const: 'https://w3id.org/mod#modSemanticArtefact' },
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
      }
    }

  end

end
