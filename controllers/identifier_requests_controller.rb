class IdentifierRequestsController < ApplicationController

  get "/ontologies/:acronym/identifier_requests" do
    acronym = params["acronym"]
    error 422, "You must provide an existing `acronym` " if acronym.nil? || acronym.empty?
    reply IdentifierRequest.where(submission: [ontology: [acronym: acronym]])
                           .include(IdentifierRequest.goo_attrs_to_load(includes_param))
                           .all
  end

  namespace "/identifier_requests" do

    ##
    # Display all IdentifierRequest
    get do
      check_last_modified_collection(LinkedData::Models::IdentifierRequest)
      id_requests = IdentifierRequest.where.include(IdentifierRequest.goo_attrs_to_load(includes_param)).all
      id_requests = id_requests.select { |r| (!r.submission.nil? && !r.submission.ontology.nil? rescue false) }
      reply id_requests
    end

    get "/all_doi_requests" do
      params["display_context"] = false
      params["display_links"] = false

      reply IdentifierRequest.where({ requestType: "DOI_CREATE" })
                             .or({ requestType: "DOI_UPDATE" })
                             .include(IdentifierRequest.goo_attrs_to_load(includes_param))
                             .include(requestedBy: [:username, :email])
                             .include(processedBy: [:username, :email])
                             .include(submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym]])
                             .all
    end

    ##
    # Display a IdentifierRequest with a specific requestId
    get "/:requestId" do
      reply find_identifier_request
    end

    get "/:requestId/submission" do

      identifier_req_obj = find_identifier_request
      identifier_req_obj.bring(submission: OntologySubmission.goo_attrs_to_load(includes_param))
      reply identifier_req_obj.submission
    end

    get "/:requestId/requestedBy" do
      identifier_req_obj = find_identifier_request
      identifier_req_obj.bring(requestedBy: User.goo_attrs_to_load(includes_param))
      reply identifier_req_obj.requestedBy
    end

    get "/:requestId/processedBy" do
      identifier_req_obj = find_identifier_request
      identifier_req_obj.bring(processedBy: User.goo_attrs_to_load(includes_param))
      reply identifier_req_obj.processedBy
    end

    ##
    # Create a IdentifierRequest
    post do
      identifier_request = create_identifier_request

      identifier_request.bring(requestedBy: [:username, :email])
      identifier_request.bring(submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym, :administeredBy, :acl, :viewingRestriction]])

      reply 201, identifier_request
    end

    ##
    # Update an IdentifierRequest
    patch '/:requestId' do
      identifier_request = find_identifier_request

      populate_from_params(identifier_request, params)
      if identifier_request.valid?
        identifier_request.save
      else
        error 422, identifier_request.errors
      end
      halt 204
    end

    # Delete ALL IdentifierRequests
    delete '/all' do
      all_identifier_requests = IdentifierRequest.where.all
      error 422, "No elements was found" if all_identifier_requests.empty?

      all_identifier_requests.each { e.delete }
      halt 204
    end

    ##
    # Delete an IdentifierRequest
    delete '/:requestId' do
      identifier_request = find_identifier_request
      identifier_request.delete
      halt 204
    end

  end

end