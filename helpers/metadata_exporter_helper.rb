require 'sinatra/base'
require_relative 'concerns/data_cite_metadata_exporter'

module Sinatra
  module Helpers
    module MetadataExporterHelper

      include Sinatra::Concerns::DataCiteMetadataExporter

      def to_data_cite_facet(submission)
        remove_empty_values(to_date_cite(submission))
      end

      private

      def remove_empty_values(hash)
        hash.each do |key, value|
          if value.is_a?(Hash)
            remove_empty_values(value)  # Recursively process nested hash
            hash.delete(key) if value.empty?  # Remove current key if nested hash is empty after processing
          elsif value.nil? || value == "" || value == []
            hash.delete(key)  # Remove key if value is nil, empty string, or empty array
          end
        end
      end

    end
  end
end

helpers Sinatra::Helpers::MetadataExporterHelper

