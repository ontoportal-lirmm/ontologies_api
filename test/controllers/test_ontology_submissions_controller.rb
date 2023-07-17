require_relative '../test_case'

class TestOntologySubmissionsController < TestCase

  def self.before_suite
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
      contact: [{name: "test_name", email: "test@example.org"}],
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

  def test_submissions_for_given_ontology
    num_onts_created, created_ont_acronyms = create_ontologies_and_submissions(ont_count: 1)
    ontology = created_ont_acronyms.first
    get "/ontologies/#{ontology}/submissions"
    assert last_response.ok?

    submissions_goo = OntologySubmission.where(ontology: { acronym: ontology}).to_a

    submissions = MultiJson.load(last_response.body)
    assert submissions.length == submissions_goo.length
  end

  def test_create_new_submission_missing_file_and_pull_location
    post "/ontologies/#{@@acronym}/submissions", name: @@name, hasOntologyLanguage: "OWL"
    assert_equal(400, last_response.status, msg=get_errors(last_response))
    assert MultiJson.load(last_response.body)["errors"]
  end

  def test_create_new_submission_file
    post "/ontologies/#{@@acronym}/submissions", @@file_params
    assert_equal(201, last_response.status, msg=get_errors(last_response))
    sub = MultiJson.load(last_response.body)
    get "/ontologies/#{@@acronym}"
    ont = MultiJson.load(last_response.body)
    assert ont["acronym"].eql?(@@acronym)
    # Cleanup
    delete "/ontologies/#{@@acronym}/submissions/#{sub['submissionId']}"
    assert_equal(204, last_response.status, msg=get_errors(last_response))
  end

  def test_create_new_ontology_submission
    post "/ontologies/#{@@acronym}/submissions", @@file_params
    assert_equal(201, last_response.status, msg=get_errors(last_response))
    # Cleanup
    sub = MultiJson.load(last_response.body)
    delete "/ontologies/#{@@acronym}/submissions/#{sub['submissionId']}"
    assert_equal(204, last_response.status, msg=get_errors(last_response))
  end

  def test_patch_ontology_submission
    num_onts_created, created_ont_acronyms = create_ontologies_and_submissions(ont_count: 1)
    ont = Ontology.find(created_ont_acronyms.first).include(submissions: [:submissionId, ontology: :acronym]).first
    assert(ont.submissions.length > 0)
    submission = ont.submissions[0]
    new_values = {description: "Testing new description changes"}
    patch "/ontologies/#{submission.ontology.acronym}/submissions/#{submission.submissionId}", MultiJson.dump(new_values), "CONTENT_TYPE" => "application/json"
    assert_equal(204, last_response.status, msg=get_errors(last_response))
    get "/ontologies/#{submission.ontology.acronym}/submissions/#{submission.submissionId}"
    submission = MultiJson.load(last_response.body)
    assert submission["description"].eql?("Testing new description changes")
  end

  def test_delete_ontology_submission
    num_onts_created, created_ont_acronyms = create_ontologies_and_submissions(ont_count: 1, random_submission_count: false, submission_count: 5)
    acronym = created_ont_acronyms.first
    submission_to_delete = (1..5).to_a.shuffle.first
    delete "/ontologies/#{acronym}/submissions/#{submission_to_delete}"
    assert_equal(204, last_response.status, msg=get_errors(last_response))

    get "/ontologies/#{acronym}/submissions/#{submission_to_delete}"
    assert_equal(404, last_response.status, msg=get_errors(last_response))
  end

  def test_download_submission
    num_onts_created, created_ont_acronyms, onts = create_ontologies_and_submissions(ont_count: 1, submission_count: 1, process_submission: false)
    assert_equal(1, num_onts_created, msg="Failed to create 1 ontology?")
    assert_equal(1, onts.length, msg="Failed to create 1 ontology?")
    ont = onts.first
    ont.bring(:submissions, :acronym)
    assert_instance_of(Ontology, ont, msg="ont is not a #{Ontology.class}")
    assert_equal(1, ont.submissions.length, msg="Failed to create 1 ontology submission?")
    sub = ont.submissions.first
    sub.bring(:submissionId)
    assert_instance_of(OntologySubmission, sub, msg="sub is not a #{OntologySubmission.class}")
    # Clear restrictions on downloads
    LinkedData::OntologiesAPI.settings.restrict_download = []
    # Download the specific submission
    get "/ontologies/#{ont.acronym}/submissions/#{sub.submissionId}/download"
    assert_equal(200, last_response.status, msg='failed download for specific submission : ' + get_errors(last_response))
    # Add restriction on download
    acronym = created_ont_acronyms.first
    LinkedData::OntologiesAPI.settings.restrict_download = [acronym]
    # Try download
    get "/ontologies/#{ont.acronym}/submissions/#{sub.submissionId}/download"
    # download should fail with a 403 status
    assert_equal(403, last_response.status, msg='failed to restrict download for ontology : ' + get_errors(last_response))
    # Clear restrictions on downloads
    LinkedData::OntologiesAPI.settings.restrict_download = []
    # see also test_ontologies_controller::test_download_ontology

    # Test downloads of nonexistent ontology
    get "/ontologies/BOGUS66/submissions/55/download"
    assert_equal(422, last_response.status, "failed to handle downloads of nonexistent ontology" + get_errors(last_response))
  end

  def test_download_ontology_submission_rdf
    count, created_ont_acronyms, onts = create_ontologies_and_submissions(ont_count: 1, submission_count: 1, process_submission: true)
    acronym = created_ont_acronyms.first
    ont = onts.first
    sub = ont.submissions.first

    get "/ontologies/#{acronym}/submissions/#{sub.submissionId}/download?download_format=rdf"
    assert_equal(200, last_response.status, msg="Download failure for '#{acronym}' ontology: " + get_errors(last_response))

    # Download should fail with a 400 status.
    get "/ontologies/#{acronym}/submissions/#{sub.submissionId}/download?download_format=csr"
    assert_equal(400, last_response.status, msg="Download failure for '#{acronym}' ontology: " + get_errors(last_response))
  end

  def test_download_acl_only
    count, created_ont_acronyms, onts = create_ontologies_and_submissions(ont_count: 1, submission_count: 1, process_submission: false)
    acronym = created_ont_acronyms.first
    ont = onts.first.bring_remaining
    ont.bring(:submissions)
    sub = ont.submissions.first
    sub.bring(:submissionId)

    begin
      allowed_user = User.new({
        username: "allowed",
        email: "test@example.org",
        password: "12345"
      })
      allowed_user.save
      blocked_user = User.new({
        username: "blocked",
        email: "test@example.org",
        password: "12345"
      })
      blocked_user.save

      ont.acl = [allowed_user]
      ont.viewingRestriction = "private"
      ont.save

      LinkedData.settings.enable_security = true

      get "/ontologies/#{acronym}/submissions/#{sub.submissionId}/download?apikey=#{allowed_user.apikey}"
      assert_equal(200, last_response.status, msg="User who is in ACL couldn't download ontology")

      get "/ontologies/#{acronym}/submissions/#{sub.submissionId}/download?apikey=#{blocked_user.apikey}"
      assert_equal(403, last_response.status, msg="User who isn't in ACL could download ontology")

      admin = ont.administeredBy.first
      admin.bring(:apikey)
      get "/ontologies/#{acronym}/submissions/#{sub.submissionId}/download?apikey=#{admin.apikey}"
      assert_equal(200, last_response.status, msg="Admin couldn't download ontology")
    ensure
      LinkedData.settings.enable_security = false
      del = User.find("allowed").first
      del.delete if del
      del = User.find("blocked").first
      del.delete if del
    end
  end

  def test_export_datacite_metadata
    hash, sub = _test_eco_portal_exporter(format: 'datacite_metadata_json')
    assert_equal sub.identifier.select{|x| x['doi.org']}.first.to_s, hash["doi"]
  end
  def test_export_ecoportal_metadata
    hash, sub = _test_eco_portal_exporter

    sub.hasOntologyLanguage.bring :acronym
    sub.contact.each{|c| c.bring_remaining }

    assert_equal sub.status, hash["status"]
    assert_equal sub.hasOntologyLanguage.acronym, hash["format"]["acronym"]
    assert_equal sub.contact.map{|c|  {"name" => c.name, "email" => c.email}}, hash["contact"]
    assert_equal sub.identifier.select{|x| x['doi.org']}.first.to_s, hash["identifier"]
    assert_equal 'DOI', hash["identifierType"]
  end

  def test_submissions_pagination
    num_onts_created, created_ont_acronyms = create_ontologies_and_submissions(ont_count: 2, submission_count: 2)

    get "/submissions"
    assert last_response.ok?
    submissions = MultiJson.load(last_response.body)

    assert_equal 2, submissions.length


    get "/submissions?page=1&pagesize=1"
    assert last_response.ok?
    submissions = MultiJson.load(last_response.body)
    assert_equal 1, submissions["collection"].length
  end

  private

  def _test_eco_portal_exporter(format: 'ecoportal_metadata_json')

    num_onts_created, created_ont_acronyms, onts = create_ontologies_and_submissions(ont_count: 1, submission_count: 1, process_submission: false)
    ontology = created_ont_acronyms.first
    onts.first.bring :submissions
    sub = onts.first.submissions.first

    sub.bring_remaining

    sub.released = DateTime.now
    sub.version = '2.4.1'
    sub.publication = [RDF::URI.new('https://test.com')]
    sub.description = "Test description"
    sub.alternative = ["alternative title 1", "alternative title 2", "alternative title 3"]
    sub.isOfType = RDF::URI.new('https://test.com/Ontology')
    sub.identifier = ['http://orcid.org/ontology/TEST', 'http://ror.org/ontology/TEST', 'http://doi.org/ontology/TEST'].map{|i| RDF::URI.new(i)}


    created_agents = [LinkedData::Models::Agent.new(name: 'publisher test', agentType: 'person', creator: @@user).save,
                      LinkedData::Models::Agent.new(name: 'publisher test 2', agentType: 'person', creator: @@user).save,
                      LinkedData::Models::Agent.new(name: 'creator 1 affiliation 2 test', agentType: 'organization', creator: @@user).save,
                      LinkedData::Models::Agent.new(name: 'creator 2 test', agentType: 'organization', creator: @@user).save,
                      LinkedData::Models::Agent.new(name: 'creator 1 affiliation 1 test', agentType: 'organization', creator: @@user).save]


    identifiers = [
      LinkedData::Models::AgentIdentifier.new(notation: 'testROR2', schemaAgency: 'ROR',creator: @@user).save,
      LinkedData::Models::AgentIdentifier.new(notation: 'testORCID', schemaAgency: 'ORCID',creator: @@user).save,
      LinkedData::Models::AgentIdentifier.new(notation: 'testROR', schemaAgency: 'ROR', creator: @@user).save
    ]
    sub.publisher = [created_agents[0], created_agents[1]]

    created_agents << LinkedData::Models::Agent.new(name: 'creator 1 affiliation 2 test',
                                                    agentType: 'organization',
                                                    creator: @@user,
                                                    identifiers: [
                                                      identifiers[0]
                                                    ],
                                                    affiliations: [
                                                      created_agents[2]
                                                    ]).save

    created_agents << LinkedData::Models::Agent.new(name: 'creator 1 test',
                                                    agentType: 'person',
                                                    creator: @@user,
                                                    identifiers: [
                                                      identifiers[1], identifiers[2]
                                                    ],
                                                    affiliations: [
                                                      created_agents[4],
                                                      created_agents[5]
                                                    ]).save
    sub.hasCreator = [created_agents[6], created_agents[3]]


    sub.save

    get "/ontologies/#{ontology}/latest_submission/#{format}"
    assert last_response.ok?
    hash = MultiJson.load(last_response.body)


    ["description", "version"].each do |key|
      assert_equal sub.send(key), hash[key]
    end

    assert_equal sub.publication.first.to_s, hash["url"]

    assert_equal sub.alternative.sort, hash["titles"].map{|x| x["title"]}.sort
    assert_equal ['AlternativeTitle'], hash["titles"].map{|x| x["titleType"]}.uniq



    assert_equal sub.isOfType.to_s.split('/').last, hash["types"]["resourceType"]
    assert_equal 'Dataset', hash["types"]["resourceTypeGeneral"]

    assert_equal sub.released.year, hash["publicationYear"]


    assert_equal sub.publisher.map{|x| x.name}.sort, hash["publisher"].split(', ').sort

    assert_equal sub.hasCreator.size, hash["creators"].size
    hash["creators"].each do |c|
      creator = sub.hasCreator.select {|creator| creator.name.eql?(c["creatorName"])}.first

      assert_equal creator.agentType.eql?('person') ? 'Personal' : 'Organizational', c["nameType"]
      assert_equal creator.name.split(' ').first, c["givenName"]
      assert_equal creator.name.split(' ').drop(1).join(' '), c["familyName"]
      assert_equal creator.name, c["creatorName"]

      assert (creator.affiliations && c["affiliations"]) || (creator.affiliations.nil? && c["affiliations"].empty?)
      assert_equal creator.affiliations.size, c["affiliations"].size if creator.affiliations && c["affiliations"]
      c["affiliations"].each do |aff|
        affiliation = creator.affiliations.select{|affiliation| affiliation.name.eql?(aff["affiliation"])}.first
        identifier = affiliation.identifiers&.first
        next if identifier.nil?

        assert_equal identifier&.schemaAgency, aff["affiliationIdentifierScheme"]
        assert_equal "#{identifier&.schemeURI}#{identifier&.notation}", aff["affiliationIdentifier"]
        assert_equal affiliation.name, aff["affiliation"]
      end

      assert (creator.identifiers && c["nameIdentifiers"]) || (creator.identifiers.nil? && c["nameIdentifiers"].empty?)
      assert_equal creator.identifiers.size, c["nameIdentifiers"].size if creator.identifiers && c["nameIdentifiers"]
      c["nameIdentifiers"].each do |nameId|

        identifier = creator.identifiers.select{|identifier| identifier.notation.eql?(nameId["nameIdentifier"])}.first
        assert_equal identifier.schemaAgency, nameId["nameIdentifierScheme"]
        assert_equal identifier.schemeURI, nameId["schemeURI"]
        assert_equal identifier.notation, nameId["nameIdentifier"]
      end
    end

    created_agents.each{|x| x.delete}
    identifiers.each { |x| x.delete }
    [hash, sub]
  end

end
