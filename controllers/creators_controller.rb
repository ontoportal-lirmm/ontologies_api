class CreatorsController < ApplicationController

  namespace "/creators" do
    get do
      check_last_modified_collection(LinkedData::Models::Creator)
      reply Creator.where.include(Creator.goo_attrs_to_load(includes_param)).all
    end

    get "/:id" do
      creator = Creator.find(params[:id]).include(Creator.goo_attrs_to_load(includes_param)).first
      error 404, "Creator not found" if creator.nil?
      reply creator
    end
  end

  namespace "/affiliations" do

    ##
    # Display all Affiliations
    get do
      check_last_modified_collection(LinkedData::Models::Affiliation)
      affiliations = Affiliation.where.include(Affiliation.goo_attrs_to_load(includes_param)).all
      reply affiliations
    end

    get "/:id" do
      affiliation = Affiliation.find(params[:id]).include(Affiliation.goo_attrs_to_load(includes_param)).first
      error 404, "Affiliation not found" if creator.nil?
      reply affiliation
    end
  end
end
