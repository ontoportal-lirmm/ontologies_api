class NewProjectNotificationJob < LinkedData::Jobs::Base
  def perform(options = {})
    return unless LinkedData::OntologiesAPI.settings.enable_notifications

    project = LinkedData::Models::Project.find(options["project_acronym"]).first
    return unless project

    project.bring(:acronym, :name)
    creator = options["creator_username"]
    
    context = {
      acronym: project.acronym,
      name: project.name,
      proj_url: LinkedData::Hypermedia.generate_links(project)['ui']
    }

    email_body = Notifier.render('new_project_subscriber_email', {context: context}, add_signature: true)
    inapp_body = Notifier.render('new_project_subscriber_inapp', {context: context})
    title = "New project created: #{project.acronym}"

    subscribers = LinkedData::Models::User.where(subscribed_to_projects: "true").include(:username, :email).to_a

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
