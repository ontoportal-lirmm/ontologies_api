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
    set :app_name, 'Pet Store API'
    set :api_version, '1.0.0'
    set :api_description, 'A sample Pet Store API'
    set :base_url, 'http://localhost:4567'

    # TODO: add them automatically
    set :api_schemas, {
      Pet: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          name: { type: 'string' },
          species: { type: 'string' }
        }
      },
      NewPet: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          species: { type: 'string' }
        },
        required: ['name', 'species']
      }
    }
  end

  doc('List all pets') do
    parameter('page', type: 'integer', description: 'Page number')
    parameter('pagesize', type: 'integer', description: 'Number of items per page')
    response(200, '', content({ type: 'array', items: { '$ref' => '#/components/schemas/Pet' } }))
    response(404, '')
  end
  get '/pets' do
    content_type :json
    [].to_json
  end

  doc('Create a pet') do
    body_parameter('pet', schema: { '$ref' => '#/components/schemas/NewPet' })
    response(201, 'Pet created', content({ '$ref' => '#/components/schemas/Pet' }))
    response(400, 'Invalid input')
  end
  post '/pets' do
    content_type :json
    request.body.rewind
    data = JSON.parse(request.body.read)
    data.to_json
  end

  doc('Delete a pet') do
    path_parameter('id', description: 'Pet ID')
    response(200, 'Pet deleted')
    response(400, 'Invalid ID')
  end
  delete '/pets/:id' do
    content_type :json
    'removed'.to_json
  end

end
