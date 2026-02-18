class Subscription < ActiveRecord::Base
  validates :user, presence: true, uniqueness: { scope: :ontology }
  validates :ontology, presence: true
  validates :notification_type, presence: true, inclusion: { in: 0..3 }

  after_initialize :set_default_values, if: :new_record?

  NOTES = 1
  PROCESSING = 2
  BOTH = NOTES | PROCESSING

  def notes?
    (notification_type & NOTES) > 0
  end

  def processing?
    (notification_type & PROCESSING) > 0
  end

  def both?
    notes? && processing?
  end

  def notes=(value)
    if value
      self.notification_type |= NOTES
    else
      self.notification_type &= ~NOTES
    end
  end

  def processing=(value)
    if value
      self.notification_type |= PROCESSING
    else
      self.notification_type &= ~PROCESSING
    end
  end

  private

  def set_default_values
    self.notification_type ||= 0
  end
end
