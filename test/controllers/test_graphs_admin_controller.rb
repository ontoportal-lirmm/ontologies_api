require_relative '../test_case'

class TestGraphAdminController < TestCase
  def setup
    ontologies = LinkedData::Models::Ontology.all
    if ontologies.empty?
      LinkedData::SampleData::Ontology.delete_ontologies_and_submissions
      @@ontologies = LinkedData::SampleData::Ontology.sample_owl_ontologies(process_submission: false)
    end
    file_path = AdminGraphsController::GRAPH_COUNT_REPORT_PATH
    File.delete(file_path) if File.exist?(file_path)
  end

  def test_initial_graphs_admin_actions
    get '/admin/graphs'
    assert last_response.ok?
    response = MultiJson.load(last_response.body)
    assert_empty response
  end

  def test_graph_creation_and_retrieval
    post '/admin/graphs'

    get '/admin/graphs'
    assert last_response.ok?
    response = MultiJson.load(last_response.body)
    refute_empty response

    response.each do |graph, count|
      assert graph.is_a?(String)
      assert count.is_a?(Array)
      assert count[0].is_a?(Integer)
      assert count[1].is_a?(TrueClass) || count[1].is_a?(FalseClass)
    end
  end

  def test_graph_deletion
    post '/admin/graphs'

    get '/admin/graphs'
    response = MultiJson.load(last_response.body)
    refute_empty response

    graph = 'http://data.bioontology.org/metadata/OntologySubmission'

    delete '/admin/graphs', url: graph

    get '/admin/graphs'
    assert last_response.ok?
    response = MultiJson.load(last_response.body)
    assert_nil response[graph]
  end
end
