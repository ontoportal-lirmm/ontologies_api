require 'haml'
require 'redcarpet'

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

      config = LinkedData::Models::PortalConfig.current_portal_config

      federated_portals = config.federated_portals
      federated_portals.transform_values! { |v| v.delete(:apikey); v }
      config.init_federated_portals_settings(federated_portals)
      config.id = RDF::URI.new(LinkedData.settings.id_url_prefix)
      config.class.link_to *routes_hash.map { |key, url| LinkedData::Hypermedia::Link.new(key, url, context[key]) }

      reply config
    end

    get "documentation" do
      @metadata_all = get_metadata_all.sort { |a, b| a[0].name <=> b[0].name }
      haml "documentation/documentation".to_sym, :layout => "documentation/layout".to_sym
    end

    private



  end
end
