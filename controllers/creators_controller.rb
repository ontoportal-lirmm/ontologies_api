class CreatorsController < ApplicationController

  # Define an array of namespace names
  namespaces = {
    creators: LinkedData::Models::Creator,
    affiliations: LinkedData::Models::Affiliation,
    contacts: LinkedData::Models::Contact
  }

  # Create dynamic namespaces from the array
  namespaces.each do |ns, model|
    namespace "/#{ns}" do
      get do
        check_last_modified_collection(model)
        reply model.where.include(model.goo_attrs_to_load(includes_param)).all
      end

      get "/:id" do
        creator = model.find(params[:id]).include(model.goo_attrs_to_load(includes_param)).first
        error 404, "#{ns.to_s[-1]} not found" if creator.nil?
        reply creator
      end
    end
  end
end
