class MappingsController < ApplicationController

  LinkedData.settings.interportal_hash ||= {}

  # Get mappings for a class
  get '/ontologies/:ontology/classes/:cls/mappings' do
    ontology = ontology_from_acronym(@params[:ontology])
    submission = ontology.latest_submission
    cls_id = @params[:cls]
    cls = LinkedData::Models::Class.find(RDF::URI.new(cls_id)).in(submission).first
    if cls.nil?
      error(404, "Class with id `#{cls_id}` not found in ontology")
    end

    mappings = LinkedData::Mappings.mappings_ontology(submission,
                                                      0, 0,
                                                      cls.id)
    populate_mapping_classes(mappings.to_a)
    reply mappings
  end

  # Get mappings for an ontology
  get '/ontologies/:ontology/mappings' do
    ontology = ontology_from_acronym(@params[:ontology])
    if ontology.nil?
      error(404, "Ontology not found")
    end
    page, size = page_params
    submission = ontology.latest_submission
    if submission.nil?
      error(404, "Submission not found for ontology " + ontology.acronym)
    end
    mappings = LinkedData::Mappings.mappings_ontology(submission,
                                                      page, size,
                                                      nil)
    populate_mapping_classes(mappings)
    reply mappings
  end



  namespace "/mappings" do
    # Display all mappings
    get do
      #ontologies = ontology_objects_from_params
      if params[:ontologies].nil?
        error(400,
              "/mappings/ endpoint only supports filtering " +
                  "on two ontologies using `?ontologies=ONT1,ONT2`")
      end
      ontologies = params[:ontologies].split(",")
      if ontologies.length != 2
        error(400,
              "/mappings/ endpoint only supports filtering " +
              "on two ontologies using `?ontologies=ONT1,ONT2`")
      end

      acr1 = ontologies[0]
      acr2 = ontologies[1]

      page, size = page_params
      if acr1.start_with?("http://") || acr1.start_with?("https://")
        ont1 = LinkedData::Models::Ontology.find(RDF::URI.new(acr1)).first
      else
        ont1 = LinkedData::Models::Ontology.find(acr1).first
      end
      if acr2.start_with?("http://") || acr2.start_with?("https://")
        ont2 = LinkedData::Models::Ontology.find(RDF::URI.new(acr2)).first
      else
        ont2 = LinkedData::Models::Ontology.find(acr2).first
      end

      if ont1.nil?
        # If the ontology given in param is external (mappings:external) or interportal (interportal:acronym)
        if acr1 == LinkedData::Models::ExternalClass.url_param_str
          sub1 = LinkedData::Models::ExternalClass.graph_uri.to_s
        elsif acr1.start_with?(LinkedData::Models::InterportalClass.base_url_param_str)
          sub1 = LinkedData::Models::InterportalClass.graph_uri(acr1.split(":")[-1]).to_s
        else
          error(404, "Submission not found for ontology #{acr1}")
        end
      else
        sub1 = ont1.latest_submission
        if sub1.nil?
          error(404, "Ontology #{acr1} not found")
        end
      end
      if ont2.nil?
        # If the ontology given in param is external (mappings:external) or interportal (interportal:acronym)
        if acr2 == LinkedData::Models::ExternalClass.url_param_str
          sub2 = LinkedData::Models::ExternalClass.graph_uri
        elsif acr2.start_with?(LinkedData::Models::InterportalClass.base_url_param_str)
          sub2 = LinkedData::Models::InterportalClass.graph_uri(acr2.split(":")[-1])
        else
          error(404, "Ontology #{acr2} not found")
        end
      else
        sub2 = ont2.latest_submission
        if sub2.nil?
          error(404, "Submission not found for ontology #{acr2}")
        end
      end
      mappings = LinkedData::Mappings.mappings_ontologies(sub1, sub2,
                                                          page, size)
      populate_mapping_classes(mappings)
      reply mappings
    end

    get "/recent" do
      check_last_modified_collection(LinkedData::Models::RestBackupMapping)
      size = params[:size] || 5
      size = Integer(size)
      if size > 50
        error 422, "Recent mappings only processes calls under 50"
      else
        mappings = LinkedData::Mappings.recent_rest_mappings(size + 15)
        populate_mapping_classes(mappings)
        reply mappings[0..size - 1]
      end
    end

    # Display a single mapping - only rest
    get '/:mapping' do
      mapping_id = request_mapping_id
      mapping = LinkedData::Mappings.get_rest_mapping(mapping_id)
      if mapping
        reply populate_mapping_classes([mapping].first)
      else
        error(404, "Mapping with id `#{mapping_id.to_s}` not found")
      end
    end

    # Create a new mapping
    post do
      begin
        mapping = LinkedData::Mappings.create_mapping(mapping_hash: params, user_creator: find_user)
        reply(201, mapping)
      rescue StandardError => e
        error(400, e.message)
      end
    end

    post '/load' do
      begin
        mappings = parse_bulk_load_file
        loaded_mappings, errors = LinkedData::Mappings.bulk_load_mappings(mappings, current_user, check_exist: true)
        response = {}
        response[:created] = loaded_mappings unless loaded_mappings.empty?
        response[:errors] = errors unless errors.empty?
        reply(201, response)
      rescue ::JSON::ParserError => e
        error(404, "File parsing error: #{e.message}")
      end
    end


    patch '/:mapping' do
      mapping = LinkedData::Mappings.get_rest_mapping(request_mapping_id)
      process = mapping.process
      populate_from_params(process, params)
      if process.valid?
        process.save
      else
        error 422, process.errors
      end
      halt 204
    end


    # Delete a mapping
    delete '/:mapping' do
      mapping_id = RDF::URI.new(replace_url_prefix(params[:mapping]))
      mapping = LinkedData::Mappings.delete_rest_mapping(mapping_id)
      if mapping.nil?
        error(404, "Mapping with id `#{mapping_id.to_s}` not found")
      else
        halt 204
      end
    end
  end

  namespace "/mappings/statistics" do

    get '/ontologies' do
      expires 86400, :public
      persistent_counts = {}
      f = Goo::Filter.new(:pair_count) == false
      LinkedData::Models::MappingCount.where.filter(f)
                                      .include(:ontologies, :count)
                                      .all
                                      .each do |m|
        persistent_counts[m.ontologies.first] = m.count
      end
      ont_acronyms = restricted_ontologies_to_acronyms(params)
      persistent_counts = persistent_counts.select { |key, _| ont_acronyms.include?(key) || key.start_with?("http://") }
      reply persistent_counts
    end

    # Statistics for an ontology
    get '/ontologies/:ontology' do
      expires 86400, :public
      ontology = ontology_from_acronym(@params[:ontology])
      if ontology.nil?
        error(404, "Ontology #{@params[:ontology]} not found")
      end
      sub = ontology.latest_submission
      if sub.nil?
        error(404, "Ontology #{@params[:ontology]} does not have a submission")
      end

      persistent_counts = {}
      LinkedData::Models::MappingCount.where(pair_count: true)
                                      .and(ontologies: ontology.acronym)
                                      .include(:ontologies, :count)
                                      .all
                                      .each do |m|
        other = m.ontologies.first
        if other == ontology.acronym
          other = m.ontologies[1]
        end
        persistent_counts[other] = m.count
      end
      reply persistent_counts
    end

    # Statistics for interportal mappings
    get '/interportal/:ontology' do
      expires 86400, :public
      if !LinkedData.settings.interportal_hash.has_key?(@params[:ontology])
        error(404, "Interportal appliance #{@params[:ontology]} is not configured")
      end
      ontology_id = LinkedData::Models::InterportalClass.graph_uri(@params[:ontology]).to_s
      persistent_counts = {}
      LinkedData::Models::MappingCount.where(pair_count: true)
          .and(ontologies: ontology_id)
          .include(:ontologies,:count)
          .all
          .each do |m|
        other = m.ontologies.first
        if other == ontology_id
          other = m.ontologies[1]
        end
        persistent_counts[other] = m.count
      end
      reply persistent_counts
    end

    # Statistics for external mappings
    get '/external' do
      expires 86400, :public
      ontology_id = LinkedData::Models::ExternalClass.graph_uri.to_s
      persistent_counts = {}
      LinkedData::Models::MappingCount.where(pair_count: true)
          .and(ontologies: ontology_id)
          .include(:ontologies,:count)
          .all
          .each do |m|
        other = m.ontologies.first
        if other == ontology_id
          other = m.ontologies[1]
        end
        persistent_counts[other] = m.count
      end
      reply persistent_counts
    end
  end
end
