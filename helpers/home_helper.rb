require 'sinatra/base'

module Sinatra
  module Helpers

    module HomeHelper

      def routes_list
        return @navigable_routes if @navigable_routes

        routes = Sinatra::Application.routes['GET']
        navigable_routes = []
        routes.each do |route|
          navigable_routes << route[0].to_s.split('?').first
        end
        @navigable_routes = navigable_routes
        navigable_routes
      end

      def routes_by_class
        {
          '/agents' => LinkedData::Models::Agent,
          '/annotator' => nil,
          '/categories' => LinkedData::Models::Category,
          '/groups' => LinkedData::Models::Group,
          '/documentation' => nil,
          '/mappings' => LinkedData::Models::Mapping,
          '/metrics' => LinkedData::Models::Metric,
          '/notes' => LinkedData::Models::Note,
          '/ontologies' => LinkedData::Models::Ontology,
          '/ontologies_full' => LinkedData::Models::Ontology,
          '/analytics' => nil,
          '/submissions' => LinkedData::Models::OntologySubmission,
          '/projects' => LinkedData::Models::Project,
          '/property_search' => nil,
          '/provisional_classes' => LinkedData::Models::ProvisionalClass,
          '/provisional_relations' => LinkedData::Models::ProvisionalRelation,
          '/recommender' => nil,
          '/replies' => LinkedData::Models::Notes::Reply,
          '/reviews' => LinkedData::Models::Review,
          '/search' => nil,
          '/slices' => LinkedData::Models::Slice,
          '/submission_metadata' => nil,
          '/ontology_metadata' => nil,
          '/users' => LinkedData::Models::User
        }
      end

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
        when (routes_list().include? resource_path) == false
          "Example: coming soon"
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

        ld_classes = ObjectSpace.each_object(Class).select { |klass| klass < LinkedData::Hypermedia::Resource }
        info = {}

        ld_classes.each do |cls|
          next unless routes_by_class.value?(cls)

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
