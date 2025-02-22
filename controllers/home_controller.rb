require 'haml'

class HomeController < ApplicationController

  CLASS_MAP = {
    Property: 'LinkedData::Models::ObjectProperty'
  }

  namespace '/' do

    get do
      expires 3600, :public
      last_modified @@root_last_modified ||= Time.now.httpdate
      routes = routes_list

      # TODO: delete when ccv will be on production
      routes.delete('/ccv')

      routes.delete('/resource_index') if LinkedData.settings.enable_resource_index == false

      routes.delete('/Agents')

      routes_hash = {}
      context = {}

      routes.each do |route|
        next unless  routes_by_class.key?(route)

        route_no_slash = route.gsub('/', '')
        context[route_no_slash] = routes_by_class[route].type_uri.to_s if routes_by_class[route].respond_to?(:type_uri)
        routes_hash[route_no_slash] = LinkedData.settings.rest_url_prefix + route_no_slash
      end

      catalog_class = LinkedData::Models::SemanticArtefactCatalog
      catalog = catalog_class.all.first || create_catalog
      attributes_to_include =  includes_param[0] == :all ? catalog_class.attributes(:all) : catalog_class.goo_attrs_to_load(includes_param)
      catalog.bring(*attributes_to_include)
      if catalog.loaded_attributes.include?(:federated_portals)
        catalog.federated_portals = catalog.federated_portals.map { |item| JSON.parse(item.gsub('=>', ':').gsub('\"', '"')) }
        catalog.federated_portals.each { |item| item.delete('apikey') }
      end
      if catalog.loaded_attributes.include?(:fundedBy)
        catalog.fundedBy = catalog.fundedBy.map { |item| JSON.parse(item.gsub('=>', ':').gsub('\"', '"')) } 
      end
      catalog.class.link_to *routes_hash.map { |key, url| LinkedData::Hypermedia::Link.new(key, url, context[key]) }
      
      reply catalog
    end

    patch do
      catalog = LinkedData::Models::SemanticArtefactCatalog.where.first
      error 422, "There is no catalog configs in the triple store" if catalog.nil?
      populate_from_params(catalog, params)
      if catalog.valid?
        catalog.save
        status 200
      else
        error 422, catalog.errors
      end
    end

    get "doc/api" do
      redirect "/documentation", 301
    end

    get "documentation" do
      @metadata_all = get_metadata_all.sort { |a, b| a[0].name <=> b[0].name }
      haml "documentation/documentation".to_sym, :layout => "documentation/layout".to_sym
    end

    private

    def create_catalog
      catalog = nil
      catalogs = LinkedData::Models::SemanticArtefactCatalog.all
      if catalogs.nil? || catalogs.empty?
          catalog = instance_from_params(LinkedData::Models::SemanticArtefactCatalog, {"test_attr_to_persist" => "test_to_persist"})
          if catalog.valid?
              catalog.save
          else
              error 422, catalog.errors
          end
      end
      catalog
  end
  

  end
end
