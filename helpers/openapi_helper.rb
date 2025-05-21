require 'sinatra/base'
require 'ostruct'

module Sinatra
  module OpenAPIHelper
    class OpenAPIDoc
      include Sinatra::OpenAPIHelper
      Parameter = Struct.new(:name, :in, :required, :type, :description, :default, :schema, keyword_init: true)
      Response = Struct.new(:description, :content, keyword_init: true)

      def initialize(tags, summary)
        @tags = tags
        @summary = summary
        @parameters = []
        @responses = {}
      end

      def to_hash
        {
          tags: @tags,
          summary: @summary,
          parameters: @parameters,
          responses: @responses
        }
      end

      def content(schema, content_type = 'application/json-ld')
        { content_type => { schema: schema } }
      end

      def response(status, description = nil, content = nil)
        @responses[status] = Response.new(description: description, content: content)
      end

      def parameter(name, in_: 'query', required: false, type: 'string', description: nil, default: nil, schema: nil)
        @parameters << Parameter.new(name: name, in: in_, required: required, type: type, description: description, default: default, schema: schema)
      end

      def path_parameter(name, required: true, type: 'string', description: nil, default: nil, schema: nil)
        parameter(name, in_: 'path', required: required, type: type, description: description, default: default, schema: schema)
      end

      def body_parameter(name, required: true, type: 'object', description: nil, schema: nil)
        parameter(name, in_: 'body', required: required, type: type, description: description, schema: schema)
      end
    end

    def doc(tags = ["default"], summary, &block)
      array_tags = tags.is_a?(Array) ? tags : [tags]
      doc = OpenAPIDoc.new(array_tags, summary)
      doc.instance_eval(&block)
      @pending_api_doc = doc.to_hash
    end

    def default_params(display: false, pagination: false, query: false)
      display_param if display
      pagination_params if pagination
      query_param if query
    end

    def default_responses(success: false, created: false, no_content: false, bad_request: false, unauthorized: false, not_found: false, server_error: false)
      response(200, "OK") if success
      response(201, "Created") if created
      response(204, "No Content") if no_content
      response(400, "Bad Request") if bad_request
      response(401, "Unauthorized") if unauthorized
      response(404, "Not Found") if not_found
      response(500, "Internal Server Error") if server_error
    end

    def display_param
      parameter('display', type: 'string', description: 'Attributes to display', default: '')
    end

    def pagination_params
      parameter('page', type: 'integer', description: 'Page number', default: '1')
      parameter('pagesize', type: 'integer', description: 'Number of items per page', default: '20')
    end

    def query_param
      parameter('q', type: 'string', description: 'Query text', default: 'plant')
    end

    def self.registered(app)
      app.before do
        @pending_api_doc = nil
      end
    end

    def route(verb, path, opts = {}, &block)
      if @pending_api_doc
        @api_docs ||= {}
        @api_docs[path.first] ||= {}
        @api_docs[path.first][verb.downcase] = @pending_api_doc
        @pending_api_doc = nil
      end
      super(verb, path, opts, &block)
    end
  end
end



