require_relative '../test/test_case'


class ImadController < ApplicationController

    namespace '/dereference_resource' do

        get do
            raise error 405, "Method Not Allowd: This route must be provided via POST request with acronym, uri, output_format parameters"
        end
        
        def set_vars
            @@acronym = "TST"
            @@name = "Test Ontology"
            @@test_file = File.expand_path("../../test/data/ontology_files/BRO_v3.1.owl", __FILE__)
            @@file_params = {
            name: @@name,
            hasOntologyLanguage: "OWL",
            administeredBy: "tim",
            "file" => Rack::Test::UploadedFile.new(@@test_file, ""),
            released: DateTime.now.to_s,
            contact: [{name: "test_name", email: "test3@example.org"}],
            URI: 'https://test.com/test',
            status: 'production',
            description: 'ontology description'
            }
            @@status_uploaded = "UPLOADED"
            @@status_rdf = "RDF"
        end
    
        def create_user
            username = "tim"
            test_user = User.new(username: username, email: "#{username}@example.org", password: "password")
            test_user.save if test_user.valid?
            @@user = test_user.valid? ? test_user : User.find(username).first
        end
    
        def create_onts
            ont = Ontology.new(acronym: @@acronym, name: @@name, administeredBy: [@@user])
        end

        post do
            set_vars()
            create_user()
            create_onts()

            acronym = params[:acronym]
            uri = params[:uri]
            output_format = params[:output_format].presence || 'jsonld'
            acronym = URI.decode_www_form_component(acronym)
            uri = URI.decode_www_form_component(uri)
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

        private

        def valid_url?(url)
            uri = URI.parse(url)
            uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        rescue URI::InvalidURIError
            false
        end
    end
end