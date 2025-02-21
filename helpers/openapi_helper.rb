require 'sinatra/base'
require 'ostruct'
module Sinatra
  module OpenAPIHelper
    class OpenAPIDoc
      Parameter = Struct.new(:name, :in, :required, :type, :description, :schema, keyword_init: true)
      Response = Struct.new(:description, :content, keyword_init: true)

      def initialize(summary)
        @summary = summary
        @parameters = []
        @responses = {}
      end

      def to_hash
        {
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

      def parameter(name, in_: 'query', required: false, type: 'string', description: nil, schema: nil)
        @parameters << Parameter.new(name: name, in: in_, required: required, type: type, description: description, schema: schema)
      end

      def path_parameter(name, required: true, type: 'string', description: nil, schema: nil)
        parameter(name, in_: 'path', required: required, type: type, description: description, schema: schema)
      end

      def body_parameter(name, required: true, type: 'object', description: nil, schema: nil)
        parameter(name, in_: 'body', required: required, type: type, description: description, schema: schema)
      end
    end

    def doc(summary, &block)
      doc = OpenAPIDoc.new(summary)
      doc.instance_eval(&block)
      @pending_api_doc = doc.to_hash
    end

    def self.registered(app)
      app.before do
        # Clear any pending documentation that wasn't used
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



