class AdminGraphsController < ApplicationController

  namespace '/admin' do
    before do
      if LinkedData.settings.enable_security && (!env['REMOTE_USER'] || !env['REMOTE_USER'].admin?)
        error 403, 'Access denied'
      end
    end

    get '/graphs' do
      file_path = NcboCron.settings.graph_counts_report_path
      output = NcboCron::GraphsCounts.new.read_graph_counts(file_path)
      reply output.to_json
    end

    post '/graphs' do
      file_path = NcboCron.settings.graph_counts_report_path
      NcboCron::GraphsCounts.new.run(Logger.new($stdout), file_path)
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
