require 'pony'

class EmailNotificationJob < LinkedData::Jobs::Base
  sidekiq_options queue: 'mailers'

  def perform(options = {})
    return unless LinkedData::OntologiesAPI.settings.enable_notifications 
    
    headers = { 'Content-Type' => 'text/html' }
    sender = options['sender'] || LinkedData::OntologiesAPI.settings.email_sender
    recipients = Array(options['recipients']).uniq
    raise ArgumentError, 'Recipient needs to be provided in options[:recipients]' if !recipients || recipients.empty?

    # By default we override all recipients to avoid
    # sending emails from testing environments.
    # Set `email_disable_override` in production
    # to send to the actual user.
    # unless LinkedData.settings.email_disable_override
    #   headers['Overridden-Sender'] = recipients
    #   recipients = LinkedData.settings.email_override
    # end
    Pony.mail({
                to: recipients,
                from: sender,
                subject: options['subject'],
                body: options['body'],
                headers: headers,
                via: :smtp,
                enable_starttls_auto: false,
                via_options: mail_options
              })

  end

  private

  def mail_options
    options = {
      address: LinkedData::OntologiesAPI.settings.smtp_host,
      port: LinkedData::OntologiesAPI.settings.smtp_port,
      domain: LinkedData::OntologiesAPI.settings.smtp_domain # the HELO domain provided by the client to the server
    }
  
    if LinkedData::OntologiesAPI.settings.smtp_auth_type && LinkedData::OntologiesAPI.settings.smtp_auth_type != :none
      options.merge!({
                       user_name: LinkedData::OntologiesAPI.settings.smtp_user,
                       password: LinkedData::OntologiesAPI.settings.smtp_password,
                       authentication: LinkedData::OntologiesAPI.settings.smtp_auth_type
                     })
    end
  
    options
  end
  def send_welcome_email(user)
    # This is a placeholder for the actual email sending logic.
    # In a real application, you would use a mailer class like Mailer.welcome_email(user).deliver_now
    puts "Sending welcome email to #{user.username} at #{user.email}"
  end
end
