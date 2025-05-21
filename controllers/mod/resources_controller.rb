class ResourcesController < ApplicationController
  namespace "/mod-api" do
    namespace "/artefacts/:artefactID/resources" do

      doc('Artefact', "Get a list of all the resources within an artefact") do
        path_parameter('artefactID', type: 'string', description: 'The acronym of the artefact', default: "STY")
        default_params(display: true, pagination: true)
        response(200, "OK", content('$ref' => '#/components/schemas/hydraPage'))
      end
      get do
        ontology, latest_submission = get_ontology_and_submission(ontology_acronym: params["artefactID"])
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
          resource_page = load_resources_hydra_page(ontology, latest_submission, model, model.goo_attrs_to_load([]), page, size_per_type)
          total_count += resource_page.aggregate
          resource_page.to_a
        end

        props_page = load_properties_hydra_page(ontology, latest_submission, page, size_per_type)
        resources.concat(props_page.to_a)
        total_count += props_page.aggregate
        reply hydra_page_object(resources, total_count)
      end

      def self.define_resource_routes(resource_types, expected_type)
        resource_types.each do |type|

          doc('Artefact', "Get a list of all #{type} within an artefact") do
            path_parameter('artefactID', type: 'string', description: 'The acronym of the artefact', default: "STY")
            default_params(display: true, pagination: true)
            response(200, "OK", content('$ref' => '#/components/schemas/hydraPage'))
          end
          get "/#{type}" do
            ontology, latest_submission = get_ontology_and_submission(ontology_acronym: params["artefactID"])
            check_access(ontology)
            model_class = (type == 'properties') ? LinkedData::Models::OntologyProperty : model_from_type(type)
            attributes, page, size = settings_params(model_class).first(3)

            if type == 'properties'
              reply load_properties_hydra_page(ontology, latest_submission, page, size)
            else
              rdf_type = LinkedData::Models::Class.class_rdf_type(latest_submission)
              if rdf_type == expected_type
                reply load_resources_hydra_page(ontology, latest_submission, model_class, attributes, page, size)
              else
                reply hydra_empty_page
              end
            end
          end


          doc('Artefact', "Get specific #{type} of a semantic artefact by it's uri") do
            path_parameter('artefactID', type: 'string', description: 'The acronym of the artefact', default: "STY")
            path_parameter('uri', type: 'string', description: 'The uri of the resource', default: "FAKE_URI")
            default_responses(success: true, not_found: true)
          end
          get "/#{type}/:uri" do
            reply resolve_resource_by_uri
          end
        end
      end

      define_resource_routes(%w[classes individuals], RDF::OWL[:Class])
      define_resource_routes(%w[concepts schemes collections labels], RDF::Vocab::SKOS[:Concept])
      define_resource_routes(%w[properties], 'properties')


      doc('Artefact', "Get a specific resources from within an artefact") do
        path_parameter('artefactID', type: 'string', description: 'The acronym of the artefact', default: "STY")
        path_parameter('uri', type: 'string', description: 'The uri of the resource', default: "FAKE_URI")
        default_responses(success: true, not_found: true)
      end
      get '/:uri' do
        reply resolve_resource_by_uri
      end
    end
  end
end
