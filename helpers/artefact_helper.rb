require 'sinatra/base'

module Sinatra
  module Helpers
    module ArtefactHelper

      def load_resources_hydra_page(ont, latest_submission, model, attributes, page, size)
        check_last_modified_segment(model, [@params["artefactID"]])
        all_count = model.where.in(latest_submission).count
        resources = model.where.in(latest_submission).include(attributes).page(page, size).page_count_set(all_count).all
        return hydra_page_object(resources.to_a, all_count)
      end

      def load_properties_hydra_page(ontology, latest_submission, page, size)
        props = ontology.properties(latest_submission)
        return hydra_page_object(props.first(size), props.length)
      end

      # Resolves a resource by its URI by first fetching its metadata from Solr,
      # then using the appropriate model to retrieve the actual data from the ontology or RDF store.
      def resolve_resource_by_uri
        uri = params['uri']
        ontology_acronym = params['artefactID']

        error 404, "The uri parameter must be provided via ?uri=<uri>" if uri.nil?

        ontology, latest_submission = get_ontology_and_submission(ontology_acronym: ontology_acronym)
        check_access(ontology)

        fq = [
          "ontology_t:\"#{ontology_acronym}\"",
          "resource_id:\"#{uri}\""
        ]

        conn = SOLR::SolrConnector.new(Goo.search_conf, :ontology_data)
        resp = conn.search("*:*", fq: fq, defType: "edismax", start: 0, rows: 1)
        doc = resp["response"]["docs"].first
        type = doc&.dig("type_t") || doc&.dig("type_txt")&.first

        error 404, "Resource with uri: #{uri} not found" unless doc

        model = model_from_type(type)

        resource =
          if model == 'property'
            ontology.property(uri, latest_submission)
          elsif model
            model.find(uri).in(latest_submission).include(model.goo_attrs_to_load(includes_param)).first
          end

        return resource
      end

      # Maps a resource type string  to its corresponding model class.
      def model_from_type(type_str)
        case type_str
        when 'class', 'classes', 'concept', 'concepts', LinkedData::Models::Class.type_uri.to_s, "http://www.w3.org/2004/02/skos/core#Concept"
          LinkedData::Models::Class
        when 'individuals', 'individual', 'instance', 'instances', LinkedData::Models::Instance.type_uri.to_s
          LinkedData::Models::Instance
        when 'property', 'properties', LinkedData::Models::AnnotationProperty.type_uri.to_s, LinkedData::Models::ObjectProperty.type_uri.to_s, LinkedData::Models::DatatypeProperty.type_uri.to_s
          'property'
        when 'scheme', 'schemes', LinkedData::Models::SKOS::Scheme.type_uri.to_s
          LinkedData::Models::SKOS::Scheme
        when 'collection', 'collections', LinkedData::Models::SKOS::Collection.type_uri.to_s
          LinkedData::Models::SKOS::Collection
        when 'label', 'labels', LinkedData::Models::SKOS::Label.type_uri.to_s
          LinkedData::Models::SKOS::Label
        else
          nil
        end
      end

      # Helper method to find artefact and handle errors
      def find_artefact(artefact_id)
        artefact = LinkedData::Models::SemanticArtefact.find(artefact_id)
        error 404, "Artefact #{artefact_id} not found" if artefact.nil?
        artefact
      end

    end
  end
end

helpers Sinatra::Helpers::ArtefactHelper
