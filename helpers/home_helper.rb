require 'sinatra/base'

module Sinatra
  module Helpers

    module HomeHelper

      def resource_collection_link(cls)
        resource = @metadata[:cls].name.split("::").last
        return "" if resource.nil?

        resource_path = "/" + resource.underscore.pluralize

        case
        when resource == "Class"
          "Example: "\
            "<a href='/ontologies/SNOMEDCT/classes/http%3A%2F%2Fpurl.bioontology.org%2Fontology%2FSNOMEDCT%2F410607006'>"\
            "/ontologies/SNOMEDCT/classes/http%3A%2F%2Fpurl.bioontology.org%2Fontology%2FSNOMEDCT%2F410607006</a>"
        when resource == "Instance"
          "Example: "\
            "<a href='/ontologies/CTX/classes/http%3A%2F%2Fwww.owl-ontologies.com%2FOntologyXCT.owl%23Eyelid/instances'>"\
            "/ontologies/CTX/classes/http%3A%2F%2Fwww.owl-ontologies.com%2FOntologyXCT.owl%23Eyelid/instances</a>"
        when resource == "Mapping"
          "Example: "\
            "<a href='/ontologies/SNOMEDCT/classes/http%3A%2F%2Fpurl.bioontology.org%2Fontology%2FSNOMEDCT%2F410607006/mappings'>"\
            "/ontologies/SNOMEDCT/classes/http%3A%2F%2Fpurl.bioontology.org%2Fontology%2FSNOMEDCT%2F410607006/mappings</a>"
        when resource == "Note"
          "Example: <a href='/ontologies/NCIT/notes'>/ontologies/NCIT/notes</a>"
        when resource == "OntologySubmission"
          "Example: "\
            "<a href='/ontologies/NCIT/submissions?display=submissionId,version'>"\
            "/ontologies/NCIT/submissions?display=submissionId,version</a>"
        else
          "Resource collection: <a href='#{resource_path}'>#{resource_path}</a>"
        end
      end


      def sample_objects
        ontology = LinkedData::Models::Ontology.read_only(id: LinkedData.settings.rest_url_prefix+"/ontologies/BRO", acronym: "BRO")
        submission = LinkedData::Models::OntologySubmission.read_only(id: LinkedData.settings.rest_url_prefix+"/ontologies/BRO/submissions/1", ontology: ontology)
        cls = LinkedData::Models::Class.read_only(id: "http://bioontology.org/ontologies/BiomedicalResourceOntology.owl#Ontology_Development_and_Management", submission: submission)
        return {
          LinkedData::Models::Ontology.type_uri => ontology,
          LinkedData::Models::Class.type_uri => cls
        }
      end


      def hypermedia_links(cls)
        cls.hypermedia_settings[:link_to]
      end

      def get_metadata_all
        return @metadata_all_info if @metadata_all_info
        info = {}
        routes_cls = [
          LinkedData::Models::Agent,
          LinkedData::Models::Category,
          LinkedData::Models::Group,
          LinkedData::Models::Mapping,
          LinkedData::Models::Metric,
          LinkedData::Models::Note,
          LinkedData::Models::Ontology,
          LinkedData::Models::OntologySubmission,
          LinkedData::Models::Project,
          LinkedData::Models::ProvisionalClass,
          LinkedData::Models::ProvisionalRelation,
          LinkedData::Models::Notes::Reply,
          LinkedData::Models::Review,
          LinkedData::Models::Slice,
          LinkedData::Models::User
        ]
        routes_cls.each do |cls|
          attributes = if cls.respond_to?(:attributes)
                         (cls.attributes(:all) + cls.hypermedia_settings[:serialize_methods]).uniq
                       else
                         cls.instance_methods(false)
                       end
          attributes_info = {}
          attributes.each do |attribute|
            next if cls.hypermedia_settings[:serialize_never].include?(attribute)

            if cls.ancestors.include?(LinkedData::Models::Base)
              model_cls = cls.range(attribute)
              type = model_cls.type_uri if model_cls.respond_to?('type_uri')

              shows_default = cls.hypermedia_settings[:serialize_default].empty? ? true : cls.hypermedia_settings[:serialize_default].include?(attribute)

              schema = cls.attribute_settings(attribute) rescue nil
              schema ||= {}
              attributes_info[attribute] = {
                type: type || '',
                shows_default: shows_default || '&nbsp;',
                unique: cls.unique?(attribute) || '&nbsp;',
                required: cls.required?(attribute) || '&nbsp;',
                list: cls.list?(attribute) || '&nbsp;',
                cardinality: (cls.cardinality(attribute) rescue nil) || '&nbsp;'
              }
            else
              attributes_info[attribute] = {
                type: '',
                shows_default: '&nbsp;',
                unique: '&nbsp;',
                required: '&nbsp;',
                list: '&nbsp;',
                cardinality: '&nbsp;'
              }
            end
          end

          cls_info = {
            attributes: attributes_info,
            uri: cls.type_uri,
            cls: cls
          }

          info[cls] = cls_info
        end

        # Sort by 'shown by default'
        info.each_value do |cls_props|
          shown = {}
          not_shown = {}
          cls_props[:attributes].each { |attr, values| values[:shows_default] ? shown[attr] = values : not_shown[attr] = values }
          cls_props[:attributes] = shown.merge(not_shown)
        end

        @metadata_all_info = info
        info
      end
    end

  end
end

helpers Sinatra::Helpers::HomeHelper
