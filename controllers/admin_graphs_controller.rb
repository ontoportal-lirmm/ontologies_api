require 'ncbo_cron/graphs_counts'
class AdminGraphsController < ApplicationController

  namespace '/admin' do
    GRAPH_COUNT_REPORT_PATH = NcboCron.settings.graphs_counts_report_path
    before do
      if LinkedData.settings.enable_security && (!env['REMOTE_USER'] || !env['REMOTE_USER'].admin?)
        error 403, 'Access denied'
      end
    end

    get '/graphs' do
      output = NcboCron::GraphsCounts.new(nil, GRAPH_COUNT_REPORT_PATH).read_graph_counts
      reply output
    end

    post '/graphs' do
      NcboCron::GraphsCounts.new(nil, GRAPH_COUNT_REPORT_PATH).run
      reply({ message: 'Graph counts generated', status: 200 })
    end

    delete '/graphs' do
      url = params['url']
      error 400, 'You must provide a valid URL for the graph to delete' if url.blank?
      Goo.sparql_data_client.delete_graph(url)
      reply({ message: "Graph #{url} deleted", status: 200 })
    end
  end
end
