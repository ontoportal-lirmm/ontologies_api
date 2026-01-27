class Notification < ActiveRecord::Base
  validates :source, presence: true
  validates :target, presence: true
  validates :title, presence: true

  scope :unseen, -> { where(seen_at: nil) }
  scope :seen, -> { where.not(seen_at: nil) }
  scope :for_target, ->(target) { where(target: target) }
  scope :from_source, ->(source) { where(source: source) }

  def mark_as_seen!
    update!(seen_at: Time.current)
  end

  def seen?
    seen_at.present?
  end
end
