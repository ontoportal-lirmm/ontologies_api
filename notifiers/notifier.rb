require 'haml'

class Notifier
  PORTAL_COLOR = LinkedData::Models::SemanticArtefactCatalog.all.first&.bring_remaining&.color || "#1da40bff"
  def self.send_welcome_email(user)
    username = user.respond_to?(:username) && user.username ? user.username : user.id.to_s.split("/").last
    
    body = render('welcome_email', {name: username}, true)

    Notification.create!(
      source: "System",
      target: username,
      title: "Welcome to AgroPortal",
      body: body,
      channels: Notification::CHANNEL_IN_APP | Notification::CHANNEL_EMAIL,
    )

    # noitfy the support team
    body = render('new_user', {username: username, email: user.email}, true)
    Notifier.notify_support("New user created", body)
  end

  def self.notify_support(subject, body)
    EmailNotificationJob.perform_async({
      "recipients" => [LinkedData::OntologiesAPI.settings.admin_emails],
      "subject" => subject,
      "body" => body
    })
  end

  def self.notify_new_ontology(ontology, user)
    body = render('new_ontology_user', context: {acronym: ontology.acronym})
    
    # Notify the support team about the new ontology
    context = {
      creator: user.username,
      acronym: ontology.acronym,
      name: ontology.name,
      ont_url: LinkedData::Hypermedia.generate_links(ontology)['ui']
    }
    body = render('new_ontology_support', {context: context}, add_signature: true)

    Notifier.notify_support("New ontology created on #{LinkedData.settings.ui_name}", body)
  end
  def self.notify_new_note(note)

    options = {
      "ontology_acronym" => note.relatedOntology.first.acronym,
      "note_id" => note.id.to_s.split("/").last,
    }
    NewNoteNotificationJob.perform_async(options)
  end  

  def self.render(template_name, locals = {}, add_signature = false)
    template_path = File.read("views/notifications/#{template_name}.html.haml")
    content = Haml::Engine.new(template_path).render(Object.new, locals)
    signature = ""
    if add_signature
      sig_path = File.read("views/notifications/_email_signature.html.haml")
      signature = Haml::Engine.new(sig_path).render
    end
    "#{content}#{signature}"
  end
  
end
