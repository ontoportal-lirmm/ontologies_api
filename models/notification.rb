require 'uri'
require_relative '../jobs/email_notification_job'

class Notification < ActiveRecord::Base
  CHANNEL_IN_APP = 1
  CHANNEL_EMAIL = 2

  validates :source, presence: true
  validates :target, presence: true
  validates :title, presence: true
  validates :channels, presence: true

  after_initialize :set_default_values, if: :new_record?
  after_create :send_email_notification

  scope :unseen, -> { where(seen_at: nil) }
  scope :seen, -> { where.not(seen_at: nil) }
  scope :for_target, ->(target) { where(target: target) }
  scope :from_source, ->(source) { where(source: source) }

  def channel_enabled?(bit)
    (channels & bit) != 0
  end

  def mark_as_seen!
    update!(seen_at: Time.current)
  end

  def seen?
    seen_at.present?
  end

  private
  
  def set_default_values
    self.source ||= "System"
    self.channels ||= CHANNEL_IN_APP
  end

  def send_email_notification
    return unless channel_enabled?(CHANNEL_EMAIL)

    user = LinkedData::Models::User.find(target).include([:email]).first
    return unless user

    EmailNotificationJob.perform_async({
      "recipients" => [user.email],
      "subject" => title,
      "body" => body
    })
  end
end
