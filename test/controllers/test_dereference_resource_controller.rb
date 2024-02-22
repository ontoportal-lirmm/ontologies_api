require_relative '../test_case'
require 'rexml/document'


class TestImadController < TestCase

    def self.before_suite
        LinkedData::SampleData::Ontology.create_ontologies_and_submissions({
            process_submission: true,
            acronym: 'INRAETHES',
            name: 'INRAETHES',
            file_path: './test/data/ontology_files/thesaurusINRAE_nouv_structure.rdf',
            ont_count: 1,
            submission_count: 1
        })
        ont = Ontology.find('INRAETHES-0').include(:acronym).first
        sub = ont.latest_submission
        sub.bring_remaining
        sub.hasOntologyLanguage = LinkedData::Models::OntologyFormat.find('SKOS').first
        sub.save
        @@graph = "http://data.bioontology.org/ontologies/INRAETHES-0/submissions/1"
        @@uri = "http://opendata.inrae.fr/thesaurusINRAE/c_6496"
    end


    def test_dereference_resource_controller_json
        skip
        post "/dereference_resource", { acronym: @@graph, uri: @@uri , output_format: "json"}
        assert last_response.ok?

        result = last_response.body
        expected_result = %(
            {
                "@context": {
                  "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
                  "skos": "http://www.w3.org/2004/02/skos/core#",
                  "owl": "http://www.w3.org/2002/07/owl#"
                },
                "@id": "http://opendata.inrae.fr/thesaurusINRAE/c_6496",
                "@type": [
                  "skos:Concept",
                  "owl:NamedIndividual"
                ],
                "skos:broader": {
                  "@id": "http://opendata.inrae.fr/thesaurusINRAE/c_a9d99f3a"
                },
                "skos:inScheme": [
                  {
                    "@id": "http://opendata.inrae.fr/thesaurusINRAE/mt_65"
                  },
                  {
                    "@id": "http://opendata.inrae.fr/thesaurusINRAE/thesaurusINRAE"
                  }
                ],
                "skos:prefLabel": {
                  "@language": "fr",
                  "@value": "altération de l'ADN"
                },
                "skos:topConceptOf": {
                  "@id": "http://opendata.inrae.fr/thesaurusINRAE/mt_65"
                }
            }
        )

        a = result.gsub(' ', '').gsub("\n", '')
        b = expected_result.gsub(' ', '').gsub("\n", '')
    
        assert_equal b, a
    end

    def test_dereference_resource_controller_xml
        post "/dereference_resource", { acronym: @@graph, uri: @@uri , output_format: "xml"}
        assert last_response.ok?

        result = last_response.body
        expected_result = %(
            <?xml version="1.0" encoding="UTF-8"?>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:skos="http://www.w3.org/2004/02/skos/core#" xmlns:owl="http://www.w3.org/2002/07/owl#">
            <skos:Concept rdf:about="http://opendata.inrae.fr/thesaurusINRAE/c_6496">
                <rdf:type rdf:resource="http://www.w3.org/2002/07/owl#NamedIndividual"/>
                <skos:broader rdf:resource="http://opendata.inrae.fr/thesaurusINRAE/c_a9d99f3a"/>
                <skos:topConceptOf rdf:resource="http://opendata.inrae.fr/thesaurusINRAE/mt_65"/>
                <skos:inScheme rdf:resource="http://opendata.inrae.fr/thesaurusINRAE/mt_65"/>
                <skos:inScheme rdf:resource="http://opendata.inrae.fr/thesaurusINRAE/thesaurusINRAE"/>
                <skos:prefLabel xml:lang="fr">altération de l'ADN</skos:prefLabel>
            </skos:Concept>
            </rdf:RDF>
        )
        a = result.gsub('\\"', '"').gsub('\\n', "").gsub(" ", "")[1..-2]
        b = expected_result.gsub(' ', '').gsub("\n", '')

        assert_equal b, a
    end

    def test_dereference_resource_controller_ntriples
        post "/dereference_resource", { acronym: @@graph, uri: @@uri , output_format: "ntriples"}
        assert last_response.ok?

        result = last_response.body
        expected_result = %(
            <http://opendata.inrae.fr/thesaurusINRAE/c_6496> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2004/02/skos/core#Concept> .
            <http://opendata.inrae.fr/thesaurusINRAE/c_6496> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#NamedIndividual> .
            <http://opendata.inrae.fr/thesaurusINRAE/c_6496> <http://www.w3.org/2004/02/skos/core#broader> <http://opendata.inrae.fr/thesaurusINRAE/c_a9d99f3a> .
            <http://opendata.inrae.fr/thesaurusINRAE/c_6496> <http://www.w3.org/2004/02/skos/core#topConceptOf> <http://opendata.inrae.fr/thesaurusINRAE/mt_65> .
            <http://opendata.inrae.fr/thesaurusINRAE/c_6496> <http://www.w3.org/2004/02/skos/core#inScheme> <http://opendata.inrae.fr/thesaurusINRAE/mt_65> .
            <http://opendata.inrae.fr/thesaurusINRAE/c_6496> <http://www.w3.org/2004/02/skos/core#inScheme> <http://opendata.inrae.fr/thesaurusINRAE/thesaurusINRAE> .
            <http://opendata.inrae.fr/thesaurusINRAE/c_6496> <http://www.w3.org/2004/02/skos/core#prefLabel> "alt\\\\u00E9rationdel'ADN"@fr .
        )
        a =  result.gsub('\\"', '"').gsub(' ', '').gsub("\\n", '')[1..-2]
        b = expected_result.gsub(' ', '').gsub("\n", '')

        assert_equal b, a
    end

    def test_dereference_resource_controller_turtle
        post "/dereference_resource", { acronym: @@graph, uri: @@uri , output_format: "turtle"}
        assert last_response.ok?
        
        result = last_response.body
        expected_result = %(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix skos: <http://www.w3.org/2004/02/skos/core#> .
            @prefix owl: <http://www.w3.org/2002/07/owl#> .
            
            <http://opendata.inrae.fr/thesaurusINRAE/c_6496>
                a owl:NamedIndividual, skos:Concept ;
                skos:broader <http://opendata.inrae.fr/thesaurusINRAE/c_a9d99f3a> ;
                skos:inScheme <http://opendata.inrae.fr/thesaurusINRAE/mt_65>, <http://opendata.inrae.fr/thesaurusINRAE/thesaurusINRAE> ;
                skos:prefLabel "altération de l'ADN" ;
                skos:topConceptOf <http://opendata.inrae.fr/thesaurusINRAE/mt_65> .
        )
        a = result.gsub('\\"','"').gsub(' ', '').gsub("\\n", '')[1..-2]
        b = expected_result.gsub(' ', '').gsub("\n", '')

        assert_equal b, a
    end

end