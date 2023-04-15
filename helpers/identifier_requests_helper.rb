require 'sinatra/base'
require_relative '../utils/utils'

module Sinatra
  module Helpers
    module IdentifierRequestsHelper

      def find_all_identifier_requests
        all_identifier_requests = IdentifierRequest.where({ requestType: "DOI_CREATE" })
                                                   .or({ requestType: "DOI_UPDATE" })
                                                   .include(IdentifierRequest.goo_attrs_to_load(includes_param))
                                                   .include(requestedBy: [:username, :email],
                                                            processedBy: [:username, :email],
                                                            submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym]])
                                                   .all
        all_identifier_requests.select { |idReqObj| (!idReqObj.submission.nil? && idReqObj.requestId == params[:id]) }
      end
      def find_identifier_request(id = params["requestId"])
        identifier_req_obj = IdentifierRequest.find(id).include(IdentifierRequest.goo_attrs_to_load(includes_param)).first
        error 404, "You must provide an existing `requestId`" unless identifier_req_obj
        identifier_req_obj
      end

      ##
      # Create a new OntologySubmission object based on the request data
      def create_identifier_request
        params = @params
        # Create OntologySubmission
        params["display"] = "all"
        identifier_request_obj = instance_from_params(IdentifierRequest, params)
        identifier_request_obj.requestId = IdentifierRequest.identifierRequest_id_generator if (identifier_request_obj.requestId.nil? || identifier_request_obj.requestId.empty?)

        if identifier_request_obj.valid?
          identifier_request_obj.save
        else
          error 400, identifier_request_obj.errors
        end
        identifier_request_obj
      end
    end
  end
end

helpers Sinatra::Helpers::IdentifierRequestsHelper
