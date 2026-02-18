class SubscriptionsController < ApplicationController
  namespace "/subscriptions" do
    get do
      user = current_user
      error 401, "You must be logged in to retrieve subscriptions" if user.username.nil?

      subscriptions = Subscription.where(user: user.username.to_s)
      subscriptions.to_json
    end

    post do
      user = current_user
      error 401, "You must be logged in to create a subscription" if user.username.nil?
      
      notification_type = params["notification_type"]
      subscription = Subscription.new(
        user: user.username.to_s,
        ontology: params["ontology"],
        notification_type: notification_type
      )

      if subscription.save
        status 201
        subscription.to_json
      else
        error 400, subscription.errors.full_messages.join(", ")
      end
    end

    patch "/:id" do
      user = current_user
      error 401, "You must be logged in to update a subscription" if user.username.nil?

      subscription = Subscription.find_by(id: params[:id], user: user.username.to_s)
      error 404, "Subscription not found" unless subscription

      subscription.notification_type = params["notification_type"].to_i

      if subscription.save
        subscription.to_json
      else
        error 400, subscription.errors.full_messages.join(", ")
      end
    end

    delete "/:id" do
      user = current_user
      error 401, "You must be logged in to delete a subscription" if user.username.nil?

      subscription = Subscription.find_by(id: params[:id], user: user.username.to_s)
      
      if subscription
        subscription.destroy
        halt 204
      else
        error 404, "Subscription not found"
      end
    end
  end

  namespace "/ontologies/:acronym" do
    get "/subscriptions" do
      subscriptions = Subscription.where(ontology: params[:acronym])
      subscriptions.to_json
    end
  end
end
