require 'sinatra/base'
require 'net/http'
require 'json'

module Sinatra
  module Helpers
    module MappingsHelper
      ##
      # Take an array of mappings and replace 'empty' classes with populated ones
      # Does a lookup in a provided hash that uses ontology uri + class id as a key
      def replace_empty_classes(mappings, populated_hash)
        mappings.each do |map|
          map.classes.each_with_index do |cls, i|
            if cls.respond_to?(:submission)
              found = populated_hash[cls.submission.ontology.id.to_s + cls.id.to_s]
            elsif cls.respond_to?(:getPrefLabel)
              # if it is an interportal or external mapping, generate the prefLabel
              cls.getPrefLabel
              found = cls
            end
            map.classes[i] = found if found
          end
        end
      end

      ##
      # Populate an array of mappings with class data retrieved from search
      def populate_mapping_classes(mappings)
        return mappings if includes_param.empty?

        # Move include param to special param so it only applies to classes
        params["include_for_class"] = includes_param
        params.delete("display")
        params.delete("include")
        env["rack.request.query_hash"] = params

        orig_classes = mappings.map {|m| m.classes }.flatten.uniq
        # Delete classes that are External or Interportal
        orig_classes.delete_if { |key| !key.respond_to?(:submission) }
        acronyms = orig_classes.map {|c| c.submission.ontology.acronym}.uniq
        classes_hash = populate_classes_from_search(orig_classes, acronyms)
        replace_empty_classes(mappings, classes_hash)

        mappings
      end

      def validate_interportal_mapping(class_id, ontology_acronym, interportal_prefix)
        # A method to check if the interportal mapping submitted is valid
        query = "#{LinkedData.settings.interportal_hash[interportal_prefix]["api"]}/ontologies/#{ontology_acronym}/classes/#{CGI.escape(class_id.to_s)}?apikey=#{LinkedData.settings.interportal_hash[interportal_prefix]["apikey"]}"
        begin
          json = ::JSON.parse(Net::HTTP.get(URI.parse(query)))
          if json["@id"] == class_id
            return true
          else
            return false
          end
        rescue => e
          error(400, "Interportal combination of class and ontology don't point to a valid class : #{e}")
        end
      end

      def uri?(string)
        uri = URI.parse(string)
        %w( http https ).include?(uri.scheme)
      rescue URI::BadURIError
        false
      rescue URI::InvalidURIError
        false
      end
      ##
      # Parse the uploaded mappings file
      def parse_bulk_load_file
        filename, tmpfile = file_from_request
        if tmpfile
          if filename.nil?
            error 400, "Failure to resolve mappings json filename from upload file."
          end
          Array(::JSON.parse(tmpfile.read,{:symbolize_names => true}))
        end

      end
      def creator_id
        params[:creator]&.start_with?("http://") ?
          params[:creator]&.split("/")[-1] : params[:creator]
      end

      def find_user
        user_id = creator_id
        user_creator = LinkedData::Models::User.find(user_id)
                                               .include(:username).first
        if user_creator.nil?
          raise StandardError, "User with id `#{params[:creator]}` not found"
        end
        user_creator
      end

      def request_mapping_id
        mapping_id = nil
        if params[:mapping] and params[:mapping].start_with?("http")
          mapping_id = RDF::URI.new(params[:mapping])
        else
          mapping_id =
            "http://data.bioontology.org/rest_backup_mappings/#{params[:mapping]}"
          mapping_id = RDF::URI.new(mapping_id)
        end
        mapping_id
      end
    end
  end
end

helpers Sinatra::Helpers::MappingsHelper