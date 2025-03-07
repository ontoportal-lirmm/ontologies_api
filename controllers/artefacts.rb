class ArtefactsController < ApplicationController

    namespace "/artefacts" do
        # Get all Semantic Artefacts
        get do
            check_last_modified_collection(LinkedData::Models::SemanticArtefact)
            attributes, page, pagesize, _, _ = settings_params(LinkedData::Models::SemanticArtefact)
            pagesize = 20 if params["pagesize"].nil?
            artefacts = LinkedData::Models::SemanticArtefact.all_artefacts(attributes, page, pagesize)
            reply artefacts
        end

        # Get one semantic artefact by ID
        get "/:artefactID" do
            artefact = LinkedData::Models::SemanticArtefact.find(params["artefactID"])
            error 404, "You must provide a valid `artefactID` to retrieve an artefact" if artefact.nil?
            check_last_modified(artefact)
            artefact.bring(*LinkedData::Models::SemanticArtefact.goo_attrs_to_load(includes_param))
            reply artefact
        end

        # Display latest distribution
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
            get do
                ontology, submission = get_latest_submission
                _, page, size = settings_params(LinkedData::Models::Class).first(3)
                size_per_route = (size / 5).to_i
                
                resource_types = [
                  LinkedData::Models::Class,
                  LinkedData::Models::Instance,
                  LinkedData::Models::SKOS::Scheme,
                  LinkedData::Models::SKOS::Collection,
                  LinkedData::Models::SKOS::Label
                ]

                resources = resource_types.flat_map do |model|
                  handle_resource_request(model, page, size_per_route, model.goo_attrs_to_load([])).to_a
                end

                reply Goo::Base::Page.new(page, size, resources.length, resources)
            end
          
            get '/classes' do
                ontology, submission = get_latest_submission
                type = LinkedData::Models::Class.class_rdf_type(submission)
                attributes, page, size = settings_params(LinkedData::Models::Class).first(3)
                
                if type == RDF::OWL[:Class]
                    attributes.reject! { |x| x.is_a?(Hash) }
                    reply handle_resource_request(LinkedData::Models::Class, page, size, attributes)
                else
                    reply empty_page(page, size)
                end
            end
          
            get '/concepts' do
                ontology, submission = get_latest_submission
                type = LinkedData::Models::Class.class_rdf_type(submission)
                attributes, page, size = settings_params(LinkedData::Models::Class).first(3)
                
                if type.to_s == "http://www.w3.org/2004/02/skos/core#Concept"
                    attributes.reject! { |x| x.is_a?(Hash) }
                    reply handle_resource_request(LinkedData::Models::Class, page, size, attributes)
                else
                    reply empty_page(page, size)
                end
            end
          
            get '/properties' do
                ont, latest_submission = get_latest_submission
                begin
                    props = ont.properties(latest_submission)
                rescue LinkedData::Models::Ontology::ParsedSubmissionError => e
                    error 404, e.message
                end
                
                _, page, size = settings_params(LinkedData::Models::OntologyProperty).first(3)
                reply Goo::Base::Page.new(page, size, props.length, props)
            end
          
            %w[individuals schemes collections labels].each do |resource_type|
                get "/#{resource_type}" do
                    model_class = case resource_type
                        when 'individuals' then LinkedData::Models::Instance
                        when 'schemes' then LinkedData::Models::SKOS::Scheme
                        when 'collections' then LinkedData::Models::SKOS::Collection
                        when 'labels' then LinkedData::Models::SKOS::Label
                    end
                    
                    attributes, page, size = settings_params(model_class).first(3)
                    attributes.reject! { |x| x.is_a?(Hash) }
                    reply handle_resource_request(model_class, page, size, attributes)
                end
            end
          
            private
            
            def empty_page(page, size)
                Goo::Base::Page.new(page, size, 0, [])
            end
            
            def handle_resource_request(model, page, size, attributes)
                _, latest_submission = get_latest_submission
                check_last_modified_segment(model, [@params["artefactID"]])
                model.where.in(latest_submission).include(attributes).page(page, size).all
            end
          
            def get_latest_submission
                @ontology ||= Ontology.find(@params["artefactID"]).first
                error 404, "You must provide a valid `artefactID` to retrieve an artefact" if @ontology.nil?
                
                check_last_modified(@ontology)
                
                @latest_submission ||= @ontology.latest_submission(status: [:RDF])
                error 404, "Artefact #{@params["artefactID"]} distribution not found." if @latest_submission.nil?
                
                unless @latest_submission.ready?(status: [:RDF])
                    error 404, "Artefact #{params["artefactID"]} distribution #{@latest_submission.submissionId} has not been parsed."
                end
                
                @latest_submission.bring(*LinkedData::Models::OntologySubmission.goo_attrs_to_load([]))
                return @ontology, @latest_submission
            end
        end

    end

end