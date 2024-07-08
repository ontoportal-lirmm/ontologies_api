require_relative '../test_case'

class TestIdentifierRequestController < TestCase

  def setup
    # Create some test groups
    @test_group = {acronym: "TEST-GROUP", name: "Test Group", description: "Description of the Test Group"}
    users = User.all
    if users.empty?
      2.times.each do
        username = "username #{rand}"
        users << User.new(username: username, email: "#{username}@example.org", password: username +'password').save
      end
    end

    @submission = OntologySubmission.where.first
    if @submission.nil?
      ont = Ontology.new(acronym: "TEST-1", name:  "TEST-1", administeredBy: [users.first], summaryOnly: true).save
      @submission = OntologySubmission.new(submissionId: 1,
                                          ontology: ont,
                                          hasOntologyLanguage: LinkedData::Models::OntologyFormat.find('OWL').first,
                                          contact: [LinkedData::Models::Contact.new(email: 'test@test.com', name: 'test').save],
                                           released: DateTime.now, uploadFilePath: '',
                                           URI: RDF::URI.new('https://test.com/test'),
                                           status: 'production',
                                           description: 'ontology description' ).save
    end

    @identifiers = {}

    5.times.each do |i|
      request_id =  i.to_s
      @identifiers[request_id] =  {
        requestId: request_id  ,
        status: LinkedData::Models::IdentifierRequestStatus::PENDING,
        requestType: LinkedData::Models::IdentifierRequestType::DOI_CREATE,
        requestedBy: users.sample,
        requestDate: DateTime.now,
        processedBy: users.sample,
        processingDate: DateTime.tomorrow.to_datetime,
        message: "message test #{rand}",
        submission: i < 3 ? @submission : nil
      }
    end

    # Make sure these don't exist
    _delete_identifiers

    # Create them again
    @identifiers.each do |id, identifier|
      IdentifierRequest.new(identifier).save
    end
  end

  def teardown
    # Delete groups
    _delete_identifiers
  end

  def _delete_identifiers
    @identifiers.each do |request_id, _|
      id = IdentifierRequest.find(request_id.to_s).first
      id.delete unless id.nil?
      assert IdentifierRequest.find(request_id.to_s).first.nil?
    end
  end

  def test_ontology_identifiers
    @submission.bring(:ontology) if @submission.bring?(:ontology)
    @submission.ontology.bring(:acronym) if @submission.ontology.bring?(:acronym)

    get "/ontologies/#{@submission.ontology.acronym}/identifier_requests"
    assert last_response.status == 200
    ids = MultiJson.load(last_response.body)
    assert_equal @identifiers.reject{|x, v| v[:submission].nil?}.size, ids.size
  end


  def test_all_identifiers_request
    get '/identifier_requests'
    assert last_response.ok?
    ids = MultiJson.load(last_response.body)
    assert_equal @identifiers.reject{|x, v| v[:submission].nil?}.size, ids.size
  end

  def test_all_doi_requests
    get '/identifier_requests/all_doi_requests'
    assert last_response.ok?
    ids = MultiJson.load(last_response.body)
    assert_equal @identifiers.length, ids.length
  end


  def test_single_doi_request
    request_id, _ = @identifiers.first

    get "identifier_requests/#{request_id}"
    assert last_response.ok?

    id = MultiJson.load(last_response.body)
    assert_equal request_id, id["requestId"]
  end

  def test_create_new_doi_request

    _, new_doi = @identifiers.first
    request_id = @identifiers.size
    new_doi[:requestId] = request_id
    new_doi[:requestedBy] = new_doi[:requestedBy].id.to_s
    new_doi[:processedBy] = new_doi[:processedBy].id.to_s
    @identifiers[request_id] = new_doi
    post "/identifier_requests", new_doi
    assert last_response.status == 201

    assert MultiJson.load(last_response.body)["requestId"].eql?(request_id.to_s)

    get "/identifier_requests/#{request_id}"
    assert last_response.ok?
    assert MultiJson.load(last_response.body)["requestId"].eql?(request_id.to_s)
  end

  def test_update_patch_doi_request
    id = IdentifierRequest.where.include(:message, :status, :requestId).first

    new_values ={
      message: "new message",
      status: LinkedData::Models::IdentifierRequestStatus::SATISFIED
    }

    refute_equal new_values[:message], id.message
    refute_equal new_values[:status], id.status

    patch "/identifier_requests/#{id.requestId}", MultiJson.dump(new_values), "CONTENT_TYPE" => "application/json"
    assert last_response.status == 204

    get "/identifier_requests/#{id.requestId}"
    assert last_response.status == 200
    new_id = MultiJson.load(last_response.body)
    assert new_id["message"].eql?(new_values[:message])
    assert new_id["status"].eql?(new_values[:status])
  end

  def test_delete_doi_request
    id = IdentifierRequest.where.include(:message, :status, :requestId).first
    @identifiers.delete(id.requestId)
    delete "/identifier_requests/#{id.requestId}"
    assert last_response.status == 204

    get "/identifier_requests/#{id.requestId}"
    assert last_response.status == 404
  end


end