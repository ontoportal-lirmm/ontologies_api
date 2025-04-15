class ArtefactsdataController < ApplicationController
  namespace "/artefacts/:artefactID/resources" do
    
    get do
      ontology, latest_submission = get_ontology_and_latest_submission
      check_access(ontology)
      _, page, size = settings_params(LinkedData::Models::Class).first(3)
      size_per_type = [size / 6, 1].max

      types = [
        LinkedData::Models::Class,
        LinkedData::Models::Instance,
        LinkedData::Models::SKOS::Scheme,
        LinkedData::Models::SKOS::Collection,
        LinkedData::Models::SKOS::Label
      ]

      total_count = 0
      resources = types.flat_map do |model|
        resource_page = load_resources_page(ontology, latest_submission, model, model.goo_attrs_to_load([]), page, size_per_type)
        total_count += resource_page.aggregate
        resource_page.to_a
      end

      props_page = load_properties_page(ontology, latest_submission, page, size_per_type)
      resources.concat(props_page.to_a)
      total_count += props_page.aggregate
      reply hydra_page_object(resources, total_count)
    end

    def self.define_resource_routes(resource_types, expected_type)
      resource_types.each do |type|
        singular = type.chomp('s')

        get "/#{type}" do
          ontology, latest_submission = get_ontology_and_latest_submission
          check_access(ontology)
          model_class = model_from_type(type)
          attributes, page, size = settings_params(model_class).first(3)
          rdf_type = LinkedData::Models::Class.class_rdf_type(latest_submission)

          if rdf_type == expected_type
            reply load_resources_page(ontology, latest_submission, model_class, attributes, page, size)
          else
            reply hydra_empty_page
          end
        end

        ["/#{type}/#{singular}", "/#{type}/:uri"].each do |path|
          get path do
            resolve_resource_by_uri
          end
        end
      end
    end

    define_resource_routes(%w[classes individuals], RDF::OWL[:Class])
    define_resource_routes(%w[concepts schemes collections labels], "http://www.w3.org/2004/02/skos/core#Concept")

    get '/properties' do
      ontology, latest_submission = get_ontology_and_latest_submission
      check_access(ontology)
      _, page, size = settings_params(LinkedData::Models::OntologyProperty).first(3)
      reply load_properties_page(ontology, latest_submission, page, size)
    end

    ['/properties/property', '/properties/:uri', '/resource', '/:uri'].each do |path|
      get path do
        resolve_resource_by_uri
      end
    end
    
  end
end
