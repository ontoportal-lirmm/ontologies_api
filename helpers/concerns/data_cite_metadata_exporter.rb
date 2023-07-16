module Sinatra
  module Concerns
    module DataCiteMetadataExporter

      def to_date_cite(sub)
        hash  = {
          url: sub.publication.first&.to_s,
          version: sub.version,
          description: sub.description,
          publicationYear: sub.released&.year,
          publisher: sub.publisher.map{|p| p.name}.join(', '),
          creators: to_data_cite_creators(sub.hasCreator),
          identifier: search_doi(sub.identifier) || sub.identifier.first&.to_s,
          identifierType: identifier_type(sub),
          titles: sub.alternative.map { |x| { title: x, titleType: 'AlternativeTitle' } },
          resourceTypeGeneral: 'Dataset',
          resourceType: sub.isOfType.to_s.split('/').last
        }

        identifier = hash.delete(:identifier)
        identifier_type = hash.delete(:identifierType)
        hash[:doi] = identifier if identifier_type.eql?('DOI')

        hash[:types] = {
          resourceTypeGeneral: hash.delete(:resourceTypeGeneral),
          resourceType: hash.delete(:resourceType),
        }
        hash
      end

      private

      def identifier_type(sub)
        identifiers = sub.identifier

        return 'None' if identifiers.nil? || identifiers.empty?

        search_doi(identifiers).nil? ? 'Other' : 'DOI'
      end

      def to_data_cite_creators(creators)
        creators.map do |creator|
          {
            nameType: creator.agentType.eql?('person') ? 'Personal' : 'Organizational',
            givenName: creator.name.split(' ').first,
            familyName: creator.name.split(' ').drop(1).join(' '),
            creatorName: creator.name,
            affiliations: to_data_cite_affiliations(creator.affiliations),
            nameIdentifiers: to_data_cite_identifiers(creator.identifiers)
          }
        end
      end

      def to_data_cite_identifiers(identifiers)
        identifiers.map do |identifier|
          {
            nameIdentifierScheme: identifier.schemaAgency,
            schemeURI: identifier.schemeURI,
            nameIdentifier: identifier.notation
          }
        end

      end

      def to_data_cite_affiliations(affiliations)
        affiliations.map do |affiliation|
          identifier = affiliation.identifiers.first
          {
            affiliationIdentifierScheme: identifier&.schemaAgency,
            affiliationIdentifier: "#{identifier&.schemeURI}#{identifier&.notation}",
            affiliation: affiliation.name
          }
        end
      end

      def search_doi(identifiers)
        identifiers.select { |i| i.start_with?('http://doi.org') || i.start_with?('https://doi.org') }.first&.to_s
      end

    end
  end
end
