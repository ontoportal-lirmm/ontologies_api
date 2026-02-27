class NewNoteNotificationJob < LinkedData::Jobs::Base
  def perform(options = {})
    return unless LinkedData::OntologiesAPI.settings.enable_notifications

    note = LinkedData::Models::Note.find(options["note_id"]).first
    return unless note

    note.bring_remaining
    ontology = note.relatedOntology.first.bring(:acronym)
    return unless ontology
    context = {
        ontology_acronym: ontology.acronym,
        subject: note.subject,
        body: note.body,
        note_url: LinkedData::Hypermedia.generate_links(ontology)['ui'] + "/?p=notes",
        username: note.creator.bring(:username).username
    }

    email_body = Notifier.render('new_note_email', {context: context}, add_signature: true)
    inapp_body = Notifier.render('new_note_inapp', {context: context})
    title = "New note on #{ontology.acronym}"      

    Notifier.notify_support(title, email_body)
    subscribers = Subscription.where(ontology: ontology.acronym)
    creator_id = note.creator.bring(:username).username
    
    subscribers.each do |subscriber|
      next if subscriber.user == creator_id
      next unless subscriber.notes?

      EmailNotificationJob.perform_async({
        "recipients" => LinkedData::Models::User.find(subscriber.user).include([:email]).first.email,
        "subject" => title,
        "body" => email_body
      })

      Notification.create(
        target: subscriber.user,
        title: title,
        body: inapp_body,
        source: "System",
        channels: Notification::CHANNEL_IN_APP 
      )
    end
  end
end
