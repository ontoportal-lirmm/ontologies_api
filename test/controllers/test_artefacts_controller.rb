require 'webrick'
require_relative '../test_case'

class TestArtefactsController < TestCase
    def before_suite
        self.backend_4s_delete
        self.class._create_onts
    end

    def after_suite
        self.backend_4s_delete
    end

    def self._create_onts
        options = {
            ont_count: 2,
            submission_count: 2,
            submissions_to_process: [1],
            process_submission: true,
            random_submission_count: false,
            process_options: {process_rdf: true, extract_metadata: false},
            acronym: "TST"
        }
        # this will create 2 ontologies (TST-0, TST-1) with 2 submissions each
        @@num_onts_created, @@created_ont_acronyms, @@ontologies = LinkedData::SampleData::Ontology.create_ontologies_and_submissions(options)
        @@ontology_0, @@ontology_0_acronym = @@ontologies[0], @@created_ont_acronyms[0]
        type = LinkedData::Models::Class.class_rdf_type(@@ontologies[0].latest_submission)
        @@ontology_type = type == RDF::OWL[:Class] ? "OWL" : "SKOS"
        @@page = 2
        @@pagesize = 1
    end

    
    def test_all_artefacts
        get "/artefacts?page=#{@@page}&pagesize=#{@@pagesize}"
        assert last_response.ok?
        artefacts_page_data = MultiJson.load(last_response.body)
        validate_page(artefacts_page_data, @@num_onts_created)
        artefacts_page_data["collection"].each do |artefact|
            assert @@created_ont_acronyms.include?(artefact["acronym"])
        end
    end

    def test_one_artefact
        get "/artefacts/#{@@ontology_0_acronym}"
        assert last_response.ok?
        artefact_data = MultiJson.load(last_response.body)
        assert_equal @@ontology_0_acronym, artefact_data["acronym"]
    end

    def test_all_distributions
        get "/artefacts/#{@@ontology_0_acronym}/distributions"
        assert last_response.ok?
        dists_page_data = MultiJson.load(last_response.body)
        assert_equal Array, dists_page_data.class
        assert_equal 2, dists_page_data.length
    end

    def test_one_distribution
        get "/artefacts/#{@@ontology_0_acronym}/distributions/1"
        assert last_response.ok?
        dist_data = MultiJson.load(last_response.body)
        assert_equal 1, dist_data["distributionId"]
    end

    def test_latest_distribution
        get "/artefacts/#{@@ontology_0_acronym}/distributions/latest"
        assert last_response.ok?
        dist_data = MultiJson.load(last_response.body)
        assert_equal 2, dist_data["distributionId"]
    end

    def test_resources
        total_count = total_resources_count
        get "/artefacts/#{@@ontology_0_acronym}/resources?page=#{@@page}&pagesize=#{@@pagesize}"
        assert last_response.ok?
        resources_page_data = MultiJson.load(last_response.body)
        validate_page(resources_page_data, total_count)
    end

    %w[classes individuals].each do |resource|
        define_method("test_#{resource}") do
            get "/artefacts/#{@@ontology_0_acronym}/resources/#{resource}?page=#{@@page}&pagesize=#{@@pagesize}"
            assert last_response.ok?
            page_data = MultiJson.load(last_response.body)
            if @@ontology_type == "OWL"
                resource_count = model_count(resource_model[resource], @@ontology_0.latest_submission)
                validate_page(page_data, resource_count)
            else
                validate_page(page_data, 0)
            end
        end
    end
    
    %w[concepts schemes collections labels].each do |resource|
        define_method("test_#{resource}") do
            get "/artefacts/#{@@ontology_0_acronym}/resources/#{resource}?page=#{@@page}&pagesize=#{@@pagesize}"
            assert last_response.ok?
            page_data = MultiJson.load(last_response.body)
            if @@ontology_type == "SKOS"
                resource_count = model_count(resource_model[resource], @@ontology_0.latest_submission)
                validate_page(page_data, resource_count)
            else
                validate_page(page_data, 0)
            end
        end
    end
    
    def test_properties
        get "/artefacts/#{@@ontology_0_acronym}/resources/properties?page=#{@@page}&pagesize=#{@@pagesize}"
        assert last_response.ok?
        properties_page_data = MultiJson.load(last_response.body)
        properties_count = @@ontology_0.properties.count
        validate_page(properties_page_data, properties_count)
    end

    private

    def validate_page(page_data, resource_count)
        assert_equal @@page, page_data["page"]
        assert_equal (resource_count/@@pagesize).to_i, page_data["pageCount"]
        assert_equal resource_count, page_data["totalCount"]
        assert page_data.key?("nextPage")
        assert page_data.key?("prevPage")
        assert page_data["collection"].is_a?(Array)
    end

    def total_resources_count
        total_count = 0
        resource_model.values.uniq.each do |model|
            total_count += model_count(model, @@ontology_0.latest_submission)
        end
        total_count += @@ontology_0.properties.count
        return total_count
    end

    def resource_model
        {
          "classes" => LinkedData::Models::Class,
          "concepts" => LinkedData::Models::Class,
          "individuals" => LinkedData::Models::Instance,
          "schemes" => LinkedData::Models::SKOS::Scheme,
          "collections" => LinkedData::Models::SKOS::Collection,
          "labels" => LinkedData::Models::SKOS::Label
        }
    end

    def model_count(model, sub)
        model.where.in(sub).count
    end

end