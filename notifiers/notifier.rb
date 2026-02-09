require 'haml'

class Notifier
  def self.send_welcome_email(user)
    
    body = render_with_signature('welcome_email', name: user.username)

    Notification.create!(
      target: user.username,
      title: "Welcome to AgroPortal",
      body: body,
      channels: Notification::CHANNEL_IN_APP | Notification::CHANNEL_EMAIL,
    )

    # noitfy the support team
    body = render_with_signature('new_user', username: user.username, email: user.email)
    Notifier.notify_support("New user created", body)
  end

  def self.notify_support(subject, body)
    EmailNotificationJob.perform_async({
      "recipients" => [LinkedData::OntologiesAPI.settings.admin_emails],
      "subject" => subject,
      "body" => body
    })
  end
  private
  
    def self.render_with_signature(template_name, locals = {})
      template_path = File.read("views/notifications/#{template_name}.html.haml")
      content = Haml::Engine.new(template_path).render(Object.new, locals)

      sig_path = File.read("views/notifications/_email_signature.html.haml")
      signature = Haml::Engine.new(sig_path).render

      "#{content}#{signature}"
    end
end
