require_relative '../test_case'

class TestImadController < TestCase

    def self.before_suite
        #LinkedData::TestCase.backend_4s_delete
=begin  
        data = %(
            @prefix ex: <http://example.org/> .
            @prefix rdf: <#{Goo.vocabulary(:rdf)}> .
            @prefix owl: <#{Goo.vocabulary(:owl)}> .
            @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

            ex:TestSubject1 rdf:type owl:Ontology .
            ex:TestSubject1 ex:TestPredicate11 "TestObject11" .
            ex:TestSubject1 ex:TestPredicate12 ex:test .
            ex:TestSubject1 ex:TestPredicate13 1 .
            ex:TestSubject1 ex:TestPredicate14 true .
            ex:TestSubject1 ex:TestPredicate15 "1.9"^^xsd:float .
            ex:TestSubject2 ex:TestPredicate2 1.9 .
        )
        graph = "http://example.org/test_graph"
        Goo.sparql_data_client.execute_append_request(graph, data, "application/x-turtle")
=end
        _set_vars
        _create_user
        _create_onts
    end


    def self._set_vars
        @@acronym = "TST"
        @@name = "Test Ontology"
        @@test_file = File.expand_path("../../data/ontology_files/BRO_v3.1.owl", __FILE__)
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

    def self._create_user
        username = "tim"
        test_user = User.new(username: username, email: "#{username}@example.org", password: "password")
        test_user.save if test_user.valid?
        @@user = test_user.valid? ? test_user : User.find(username).first
    end

    def self._create_onts
        ont = Ontology.new(acronym: @@acronym, name: @@name, administeredBy: [@@user])
        ont.save
    end

    def submit_ontology
        post "/ontologies/#{@@acronym}/submissions", @@file_params
        assert_equal(201, last_response.status, msg=get_errors(last_response))
        sub = MultiJson.load(last_response.body)
        get "/ontologies/#{@@acronym}"
        ont = MultiJson.load(last_response.body)
        assert ont["acronym"].eql?(@@acronym)
    end


    def test_imad_controller
        submit_ontology()
        
        post "/dereference_resource", { acronym: "http://data.bioontology.org/ontologies/TST/submissions/1", uri: "http://data.bioontology.org/users/tim" }
        puts
        puts last_response.body
        puts
        assert last_response.ok?


        post "/dereference_resource", { acronym: "http://data.bioontology.org/ontologies/TST/submissions/1", uri: "http://data.bioontology.org/users/tim", output_format: "json"}
        puts
        puts last_response.body
        puts
        assert last_response.ok?


        post "/dereference_resource", { acronym: "http://data.bioontology.org/ontologies/TST/submissions/1", uri: "http://data.bioontology.org/users/tim", output_format: "xml"}
        puts
        puts last_response.body
        puts
        assert last_response.ok?


        post "/dereference_resource", { acronym: "http://data.bioontology.org/ontologies/TST/submissions/1", uri: "http://data.bioontology.org/users/tim", output_format: "ntriples"}
        puts
        puts last_response.body
        puts
        assert last_response.ok?


        post "/dereference_resource", { acronym: "http://data.bioontology.org/ontologies/TST/submissions/1", uri: "http://data.bioontology.org/users/tim", output_format: "turtle"}
        puts
        puts last_response.body
        puts
        assert last_response.ok?
        
        # Cleanup
        #delete "/ontologies/#{@@acronym}/submissions/#{sub['submissionId']}"
        #assert_equal(204, last_response.status, msg=get_errors(last_response))
    
   end

end