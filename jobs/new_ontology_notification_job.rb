class NewOntologyNotificationJob < LinkedData::Jobs::Base
  def perform(options = {})
    return unless LinkedData::OntologiesAPI.settings.enable_notifications

    ontology = LinkedData::Models::Ontology.find(options["ontology_acronym"]).first
    return unless ontology

    ontology.bring(:acronym, :name)
    creator = options["creator_username"]
    
    context = {
      acronym: ontology.acronym,
      name: ontology.name,
      ont_url: LinkedData::Hypermedia.generate_links(ontology)['ui']
    }

    email_body = Notifier.render('new_ontology_subscriber_email', {context: context}, add_signature: true)
    inapp_body = Notifier.render('new_ontology_subscriber_inapp', {context: context})
    title = "New ontology created: #{ontology.acronym}"

    subscribers = LinkedData::Models::User.where(subscribed_to_ontologies: "true").include(:username, :email).to_a

    subscribers.each do |subscriber|
      # Don't notify the creator twice (they already get a separate notification usually)
      next if subscriber.username == creator

      # Send email notification
      EmailNotificationJob.perform_async({
        "recipients" => [subscriber.email],
        "subject" => title,
        "body" => email_body
      })

      # Create in-app notification
      Notification.create(
        target: subscriber.username,
        title: title,
        body: inapp_body,
        source: "System",
        channels: Notification::CHANNEL_IN_APP
      )
    end
  end
end
