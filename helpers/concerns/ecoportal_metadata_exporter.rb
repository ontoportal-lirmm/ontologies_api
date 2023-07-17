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
    end
  end
end
