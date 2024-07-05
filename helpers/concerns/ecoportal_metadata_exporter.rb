require_relative './data_cite_metadata_exporter'
module Sinatra
  module Concerns
    module EcoPortalMetadataExporter
      include DataCiteMetadataExporter

      def to_eco_portal(sub)

        hash = {
          homepage: sub.homepage,
          documentation: sub.documentation,
          ontology: { acronym: sub.ontology.acronym, name: sub.ontology.name },
          format: { acronym: sub.hasOntologyLanguage&.acronym },
          url: sub.publication.first&.to_s,
          version: sub.version,
          description: sub.description,
          publicationYear: sub.released&.year,
          publisher: sub.publisher.map { |p| p.name }.join(', '),
          status: sub.status,
          contact: sub.contact.map { |x| { name: x.name, email: x.email } },
          identifier: search_doi(sub.identifier) || sub.identifier.first&.to_s,
          identifierType: identifier_type(sub),
          creators: to_data_cite_creators(sub.hasCreator),
          titles: sub.alternative.map { |x| { title: x, titleType: 'AlternativeTitle' } },
          resourceTypeGeneral: 'Dataset',
          resourceType: sub.isOfType.to_s.split('/').last
        }

        hash.delete(:identifier) if hash[:identifierType].eql?('None')

        hash[:types] = {
          resourceTypeGeneral: hash.delete(:resourceTypeGeneral),
          resourceType: hash.delete(:resourceType),
        }
        hash
      end

      def old_eco_portal_adapter(params, ont)
        params["publication"] = Array(params["publication"])

        params["alternative"] = params["titles"].map{ |x| x['title'] } if params["titles"].present?

        params.delete("publicationYear")
        params.delete("resourceTypeGeneral")

        params["hasFormalityLevel"] = "http://w3id.org/nkos/nkostype##{params["resourceType"].gsub(' ','_').downcase}" if params["resourceType"].present?

        if params["creators"].present?
          params["hasCreator"] = Array(params["creators"]).map do |creator|
            name = creator['creatorName']
            next nil if name.blank?

            agent = LinkedData::Models::Agent.where(agentType: 'person', name: name).first
            agent ||= LinkedData::Models::Agent.new(name: name, agentType: 'person', creator: current_user).save
            agent.id.to_s
          end
        end

        if params["publisher"].present?
          name = params["publisher"]
          agent = LinkedData::Models::Agent.where(name: name).first
          agent ||= LinkedData::Models::Agent.new(name: name, agentType: 'organization', creator: current_user).save
          params["publisher"] = [agent.id.to_s]
        end


        unless params["URI"].present?
          params["URI"] = ont.id
        end
        params
      end
    end
  end
end
