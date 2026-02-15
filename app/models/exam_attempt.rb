class ExamAttempt < ApplicationRecord
  belongs_to :exam_blueprint
  belongs_to :question_bank
  belongs_to :license_category, optional: true

  has_many :exam_attempt_items, dependent: :destroy

  before_validation :ensure_uuid, on: :create

  enum :status, {
    in_progress: 0,
    submitted: 1,
    expired: 2,
    cancelled: 3
  }, prefix: true

  validates :uuid, presence: true, uniqueness: true
  validates :locale, inclusion: { in: DrivingTestConstants::LOCALES }
  validates :started_at, :deadline_at, presence: true
  validates :max_score, numericality: { only_integer: true, greater_than: 0 }
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :deadline_not_before_start
  validate :score_not_above_max_score

  def to_param
    uuid
  end

  private

  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def deadline_not_before_start
    return if started_at.blank? || deadline_at.blank?
    return if deadline_at >= started_at

    errors.add(:deadline_at, "must be on or after started_at")
  end

  def score_not_above_max_score
    return if score.blank? || max_score.blank?
    return if score <= max_score

    errors.add(:score, "must not exceed max_score")
  end
end
