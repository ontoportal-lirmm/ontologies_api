require_relative '../test/test_case'


class DereferenceResourceController < ApplicationController

    namespace '/dereference_resource' do
        
        get do
            reply "GET: /:acronym/:uri?output_format= OR POST: acronym, uri, output_format parameters"
        end

        get "/:acronym/:uri" do
            acronym = params[:acronym]
            uri = params[:uri]
            output_format = params[:output_format].presence || 'jsonld'
            process_request(acronym, uri, output_format)
        end


        post do

            acronym = params[:acronym]
            uri = params[:uri]
            output_format = params[:output_format].presence || 'jsonld'
            process_request(acronym, uri, output_format)
        end

        private

        def process_request(acronym_param, uri_param, output_format)
            acronym = URI.decode_www_form_component(acronym_param)
            uri = URI.decode_www_form_component(uri_param)
            unless valid_url?(acronym) && valid_url?(uri)
                raise error 500, "INVALID URLs"
                return
            end

            r = Resource.new(acronym, uri)
            case output_format
            when 'jsonld'
                content_type 'application/json'
                reply  JSON.parse(r.to_json)
            when 'json'
                content_type 'application/json'
                reply JSON.parse(r.to_json)
            when 'xml'
                content_type 'application/xml'
                reply r.to_xml
            when 'turtle'
                content_type 'text/turtle'
                reply r.to_turtle
            when 'ntriples'
                content_type 'application/n-triples'
                reply r.to_ntriples
            else
                raise error 500, "Invalid output format"
            end

        end

        def valid_url?(url)
            uri = URI.parse(url)
            uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        rescue URI::InvalidURIError
            false
        end
    end
end