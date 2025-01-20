require_relative '../test_case'
require "multi_json"

class TestLoggingController < TestCase

  def setup
    Goo.use_cache = true
    Goo.redis_client.flushdb
    Goo.add_query_logger(enabled: true, file: "./queries.log")
  end
  def teardown
    Goo.add_query_logger(enabled: false, file: nil)
    File.delete("./queries.log") if File.exist?("./queries.log")
    Goo.redis_client.flushdb
    Goo.use_cache = false
  end

  def test_logging_endpoint
    LinkedData::Models::Ontology.where.include(:acronym).all
    get '/admin/latest_query_logs'
    assert last_response.ok?
    logs = MultiJson.load(last_response.body)
    assert logs
  end
end
