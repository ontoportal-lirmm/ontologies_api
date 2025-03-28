class ArtefactsController < ApplicationController

    namespace "/artefacts" do
        # Get all Semantic Artefacts

        doc('Get the list all artefacts') do
            parameter('page', type: 'integer', description: 'Page number', default: '1')
            parameter('pagesize', type: 'integer', description: 'Number of items per page', default: '50')
            parameter('display', type: 'string', description: 'Attributes to display', default: '')
            response(200, '', content( '$ref' => '#/components/schemas/artefacts' ))
        end
        get do
            check_last_modified_collection(LinkedData::Models::SemanticArtefact)
            attributes, page, pagesize, _, _ = settings_params(LinkedData::Models::SemanticArtefact)
            pagesize = 20 if params["pagesize"].nil?
            artefacts = LinkedData::Models::SemanticArtefact.all_artefacts(LinkedData::Models::SemanticArtefact.goo_attrs_to_load([]), page, pagesize)
            reply artefacts
        end

        # Get one semantic artefact by ID
        doc('Get one artefacts') do
            path_parameter('artefactID', type: 'string', description: 'Id de l\'artefact', default: 'INRAETHES')
            parameter('display', type: 'string', description: 'Attributes to display', default: '')
            response(200, 'return a specific artefact', content( '$ref' => '#/components/schemas/modSemanticArtefact' ))
            response(404, 'The artefact was not found', content( '$ref' => '#/components/schemas/error' ))
        end
        get "/:artefactID" do
            artefact = LinkedData::Models::SemanticArtefact.find(params["artefactID"])
            error 404, "You must provide a valid `artefactID` to retrieve an artefact" if artefact.nil?
            check_last_modified(artefact)
            artefact.bring(*LinkedData::Models::SemanticArtefact.goo_attrs_to_load(includes_param))
            reply artefact
        end

        get "/:artefactID/record" do
            record = LinkedData::Models::SemanticArtefactCatalogRecord.find(params["artefactID"])
            error 404, "You must provide a valid `artefactID` to retrieve ats record" if record.nil?
            check_last_modified(record)
            record.bring(*LinkedData::Models::SemanticArtefactCatalogRecord.goo_attrs_to_load(includes_param))
            reply record
        end

        # Display latest distribution
        doc('Get latest distribution') do
            path_parameter('artefactID', type: 'string', description: 'Id de l\'artefact', default: 'INRAETHES')
            parameter('display', type: 'string', description: 'Attributes to display', default: '')
            response(200, 'return the latest distribution of artefact', content( '$ref' => '#/components/schemas/modSemanticArtefactDistribution'))
            response(404, 'The artefact was not found', content( '$ref' => '#/components/schemas/error' ))
        end
        get "/:artefactID/distributions/latest" do
            artefact = LinkedData::Models::SemanticArtefact.find(params["artefactID"])
            error 404, "You must provide a valid artefactID to retrieve an artefact" if artefact.nil?
            include_status = params["include_status"] && !params["include_status"].empty? ? params["include_status"].to_sym : :any
            latest_distribution = artefact.latest_distribution(status: include_status)

            if latest_distribution
                check_last_modified(latest_distribution)
                latest_distribution.bring(*LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load(includes_param))
            end
            reply latest_distribution
        end

        # Display a distribution
        doc('Get distribution by id') do
            path_parameter('artefactID', type: 'string', description: 'Id de l\'artefact', default: 'INRAETHES')
            path_parameter('distributionID', type: 'integer', description: 'Id of distribution', default: '9')
            parameter('display', type: 'string', description: 'Attributes to display', default: '')
            response(200, 'return the latest distribution of artefact', content( '$ref' => '#/components/schemas/modSemanticArtefactDistribution'))
            response(404, 'The artefact/distribution was not found', content( '$ref' => '#/components/schemas/error' ))
        end
        get '/:artefactID/distributions/:distributionID' do
            artefact = LinkedData::Models::SemanticArtefact.find(params["artefactID"])
            error 422, "Semantic Artefact #{params["artefactID"]} does not exist" unless artefact
            check_last_modified_segment(LinkedData::Models::SemanticArtefactDistribution, [params["artefactID"]])
            artefact_distribution = artefact.distribution(params["distributionID"])
            error 404, "Distribuution with #{params['distributionID']} not found" if artefact_distribution.nil?
            artefact_distribution.bring(*LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load(includes_param))
            reply artefact_distribution
        end

        # Display a distribution

        doc('Get the list all distributions of an artefact') do
            path_parameter('artefactID', type: 'string', description: 'Id de l\'artefact', default: 'INRAETHES')
            parameter('display', type: 'string', description: 'Attributes to display', default: '')
            response(200, 'return the list of distribution of a the artefact with id :artefactID', content( '$ref' => '#/components/schemas/distributions'))
            response(404, 'Semantic artefact does not exist', content( '$ref' => '#/components/schemas/error' ))
        end
        get '/:artefactID/distributions' do
            artefact = LinkedData::Models::SemanticArtefact.find(params["artefactID"])
            error 404, "Semantic Artefact #{params["acronym"]} does not exist" unless artefact
            check_last_modified_segment(LinkedData::Models::SemanticArtefactDistribution, [params["artefactID"]])
            options = {
                status: (params["include_status"] || "ANY"),
                includes: LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load([])
            }
            distros = artefact.all_distributions(options)
            reply distros.sort {|a,b| b.distributionId.to_i <=> a.distributionId.to_i }
        end

        # Ressources
        namespace "/:artefactID/resources" do
            doc('Get the list all resources of an artefact') do
                path_parameter('artefactID', type: 'string', description: 'Id de l\'artefact', default: 'INRAETHES')
                parameter('page', type: 'integer', description: 'Page number', default: '1')
                parameter('pagesize', type: 'integer', description: 'Number of items per page', default: '50')
                parameter('display', type: 'string', description: 'Attributes to display', default: '')
                response(200, 'return the list of resources of a the artefact with id :artefactID', content( '$ref' => '#/components/schemas/page'))
                response(404, 'You must provide a valid `artefactID` to retrieve an artefact', content( '$ref' => '#/components/schemas/error' ))
            end
            get do
                ontology, latest_submission = get_ontology_and_latest_submission
                check_access(ontology)
                _, page, size = settings_params(LinkedData::Models::Class).first(3)
                size_per_route = size < 6 ? size : (size / 6).to_i

                resource_types = [
                  LinkedData::Models::Class,
                  LinkedData::Models::Instance,
                  LinkedData::Models::SKOS::Scheme,
                  LinkedData::Models::SKOS::Collection,
                  LinkedData::Models::SKOS::Label
                ]

                resources = resource_types.flat_map do |model|
                    handle_resources_request(ontology, latest_submission, model, model.goo_attrs_to_load([]), page, size_per_route).to_a
                end

                # add properties because there is no specific model for it
                props_page, props_count = handle_properties_request(ontology, latest_submission, page, size_per_route)
                resources.concat(props_page.to_a)

                resouces_count = 0
                resource_types.each do |model|
                    resouces_count += model.where.in(latest_submission).count
                end
                resouces_count += props_count

                reply page_object(resources, resouces_count)
            end

            doc('Get the list all classes of an OWL artefact') do
                path_parameter('artefactID', type: 'string', description: 'Id de l\'artefact', default: 'INRAETHES')
                parameter('page', type: 'integer', description: 'Page number', default: '1')
                parameter('pagesize', type: 'integer', description: 'Number of items per page', default: '50')
                parameter('display', type: 'string', description: 'Attributes to display', default: '')
                response(200, 'return a page of classes for the artefact with id :artefactID', content( '$ref' => '#/components/schemas/page'))
                response(404, 'You must provide a valid `artefactID` to retrieve an artefact', content( '$ref' => '#/components/schemas/error' ))
            end
            get '/classes' do
                ontology, latest_submission = get_ontology_and_latest_submission
                check_access(ontology)
                type = LinkedData::Models::Class.class_rdf_type(latest_submission)
                attributes, page, size = settings_params(LinkedData::Models::Class).first(3)
                
                if type == RDF::OWL[:Class]
                    reply handle_resources_request(ontology, latest_submission, LinkedData::Models::Class, attributes, page, size)
                else
                    reply empty_page
                end
            end

            doc('Get the list all concepts of a SKOS artefact') do
                path_parameter('artefactID', type: 'string', description: 'Id de l\'artefact', default: 'INRAETHES')
                parameter('page', type: 'integer', description: 'Page number', default: '1')
                parameter('pagesize', type: 'integer', description: 'Number of items per page', default: '50')
                parameter('display', type: 'string', description: 'Attributes to display', default: '')
                response(200, 'return a page of concepts for the artefact with id :artefactID', content( '$ref' => '#/components/schemas/page'))
                response(404, 'You must provide a valid `artefactID` to retrieve an artefact', content( '$ref' => '#/components/schemas/error' ))
            end
            get '/concepts' do
                ontology, latest_submission = get_ontology_and_latest_submission
                check_access(ontology)
                type = LinkedData::Models::Class.class_rdf_type(latest_submission)
                attributes, page, size = settings_params(LinkedData::Models::Class).first(3)
                
                if type.to_s == "http://www.w3.org/2004/02/skos/core#Concept"
                    reply handle_resources_request(ontology, latest_submission, LinkedData::Models::Class, attributes, page, size)
                else
                    reply empty_page
                end
            end

            doc('Get the list all properties of an artefact') do
                path_parameter('artefactID', type: 'string', description: 'Id de l\'artefact', default: 'INRAETHES')
                parameter('page', type: 'integer', description: 'Page number', default: '1')
                parameter('pagesize', type: 'integer', description: 'Number of items per page', default: '50')
                parameter('display', type: 'string', description: 'Attributes to display', default: '')
                response(200, 'return the page of properties of a the artefact with id :artefactID', content( '$ref' => '#/components/schemas/page'))
                response(404, 'You must provide a valid `artefactID` to retrieve an artefact', content( '$ref' => '#/components/schemas/error' ))
            end
            get '/properties' do
                ontology, latest_submission = get_ontology_and_latest_submission
                check_access(ontology)
                _, page, size = settings_params(LinkedData::Models::OntologyProperty).first(3)
                props_page, _ = handle_properties_request(ontology, latest_submission, page, size)
                reply props_page
            end

            doc('Get the list all individuals of an OWL artefact') do
                path_parameter('artefactID', type: 'string', description: 'Id de l\'artefact', default: 'INRAETHES')
                parameter('page', type: 'integer', description: 'Page number', default: '1')
                parameter('pagesize', type: 'integer', description: 'Number of items per page', default: '50')
                parameter('display', type: 'string', description: 'Attributes to display', default: '')
                response(200, 'return the page of individuals of a the artefact with id :artefactID', content( '$ref' => '#/components/schemas/page'))
                response(404, 'You must provide a valid `artefactID` to retrieve an artefact', content( '$ref' => '#/components/schemas/error' ))
            end
            get '/individuals' do
                ontology, latest_submission = get_ontology_and_latest_submission
                check_access(ontology)
                type = LinkedData::Models::Class.class_rdf_type(latest_submission)
                attributes, page, size = settings_params(LinkedData::Models::Instance).first(3)
                if type == RDF::OWL[:Class]
                    reply handle_resources_request(ontology, latest_submission, LinkedData::Models::Instance, attributes, page, size)
                else
                    reply empty_page
                end
            end
          
            %w[schemes collections labels].each do |resource_type|
                doc("Get the list all #{resource_type} of a SKOS artefact") do
                    path_parameter('artefactID', type: 'string', description: 'Id de l\'artefact', default: 'INRAETHES')
                    parameter('page', type: 'integer', description: 'Page number', default: '1')
                    parameter('pagesize', type: 'integer', description: 'Number of items per page', default: '50')
                    parameter('display', type: 'string', description: 'Attributes to display', default: '')
                    response(200, "return the page of #{resource_type} of a the artefact with id :artefactID", content( '$ref' => '#/components/schemas/page'))
                    response(404, 'You must provide a valid `artefactID` to retrieve an artefact', content( '$ref' => '#/components/schemas/error' ))
                end
                get "/#{resource_type}" do
                    model_class = case resource_type
                        when 'schemes' then LinkedData::Models::SKOS::Scheme
                        when 'collections' then LinkedData::Models::SKOS::Collection
                        when 'labels' then LinkedData::Models::SKOS::Label
                    end

                    ontology, latest_submission = get_ontology_and_latest_submission
                    check_access(ontology)
                    attributes, page, size = settings_params(model_class).first(3)
                    type = LinkedData::Models::Class.class_rdf_type(latest_submission)
                    if type.to_s == "http://www.w3.org/2004/02/skos/core#Concept"
                        reply handle_resources_request(ontology, latest_submission, model_class, attributes, page, size)    
                    else
                        reply empty_page
                    end
                    
                end
            end

            get '/resource' do
                fetch_resource
            end

            get '/:uri' do
                fetch_resource
            end

            private

            def handle_resources_request(ont, latest_submission, model,  attributes, page, size)
                check_last_modified_segment(model, [@params["artefactID"]])
                model.where.in(latest_submission).include(attributes).page(page, size).all
            end

            def handle_properties_request(ontology, latest_submission, page, size)
                props = ontology.properties(latest_submission)
                page = Goo::Base::Page.new(page, size, props.length, props.first(size))
                return page, props.length
            end
          
            def get_ontology_and_latest_submission
                @ontology ||= Ontology.find(@params["artefactID"]).include(:acronym, :administeredBy, :acl, :viewingRestriction).first
                error 404, "You must provide a valid `artefactID` to retrieve an artefact" if @ontology.nil?
                
                check_last_modified(@ontology)
                
                @latest_submission ||= @ontology.latest_submission(status: [:RDF])
                error 404, "Artefact #{@params["artefactID"]} distribution not found." if @latest_submission.nil?
                
                unless @latest_submission.ready?(status: [:RDF])
                    error 404, "Artefact #{params["artefactID"]} distribution #{@latest_submission.submissionId} has not been parsed."
                end
                @latest_submission.bring(ontology: [:acronym])
                return @ontology, @latest_submission
            end
            
            def fetch_resource
                uri = params['uri']
                ontology_acronym = params['artefactID']
                
                error 404, "The uri parameter must be provided via ?uri=<uri>" if uri.nil?
              
                ontology, latest_submission = get_ontology_and_latest_submission
                check_access(ontology)
              
                fq = [
                  "ontology_t:\"#{ontology_acronym}\"",
                  "resource_id:\"#{uri}\""
                ]
                conn = SOLR::SolrConnector.new(Goo.search_conf, :ontology_data)
                resp = conn.search("*:*", fq: fq, defType: "edismax", start: 0, rows: 1)
                doc = resp["response"]["docs"].first

                if doc
                  type = doc["type_t"] || doc["type_txt"].first
              
                  resource = case type
                             when LinkedData::Models::Class.type_uri.to_s, "http://www.w3.org/2004/02/skos/core#Concept"
                               LinkedData::Models::Class.find(uri).in(latest_submission).include(LinkedData::Models::Class.goo_attrs_to_load(includes_param)).first
                             when LinkedData::Models::Instance.type_uri.to_s
                               LinkedData::Models::Instance.find(uri).in(latest_submission).include(LinkedData::Models::Instance.goo_attrs_to_load(includes_param)).first
                             when LinkedData::Models::AnnotationProperty.type_uri.to_s, LinkedData::Models::ObjectProperty.type_uri.to_s, LinkedData::Models::DatatypeProperty.type_uri.to_s
                               ontology.property(uri, latest_submission)
                             when LinkedData::Models::SKOS::Scheme.type_uri.to_s
                               LinkedData::Models::SKOS::Scheme.find(uri).in(latest_submission).include(LinkedData::Models::SKOS::Scheme.goo_attrs_to_load(includes_param)).first
                             when LinkedData::Models::SKOS::Collection.type_uri.to_s
                               LinkedData::Models::SKOS::Collection.find(uri).in(latest_submission).include(LinkedData::Models::SKOS::Collection.goo_attrs_to_load(includes_param)).first
                             when LinkedData::Models::SKOS::Label.type_uri.to_s
                               LinkedData::Models::SKOS::Label.find(uri).in(latest_submission).include(LinkedData::Models::SKOS::Label.goo_attrs_to_load(includes_param)).first
                             else
                               doc
                             end              
                  reply resource
                else
                  error 404, "Resource with uri: #{uri} not found"
                end
            end

        end
    end
    
    namespace "/records" do
        get do
            check_last_modified_collection(LinkedData::Models::SemanticArtefactCatalogRecord)
            attributes, page, pagesize, _, _ = settings_params(LinkedData::Models::SemanticArtefactCatalogRecord)
            pagesize = 20 if params["pagesize"].nil?
            records = LinkedData::Models::SemanticArtefactCatalogRecord.all(attributes, page, pagesize)
            reply records
        end

        # Get all records on an artefacts (records => submissions)
        get "/:artefactID" do
            record = LinkedData::Models::SemanticArtefactCatalogRecord.find(params["artefactID"])
            error 404, "You must provide a valid `artefactID` to retrieve ats record" if record.nil?
            check_last_modified(record)
            records_of_artefact = record.artefact_all_records(LinkedData::Models::SemanticArtefactCatalogRecord.goo_attrs_to_load(includes_param))
            reply records_of_artefact
        end
    end

end