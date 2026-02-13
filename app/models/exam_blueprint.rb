class ExamBlueprint < ApplicationRecord
  has_many :exam_blueprint_rules, dependent: :destroy
  has_many :exam_attempts, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validates :questions_total, :basic_questions_count, :specialist_questions_count,
            :duration_minutes, :pass_score, :max_score,
            numericality: { only_integer: true, greater_than: 0 }
  validate :parts_sum_matches_total
  validate :pass_score_not_above_max_score
  validate :effective_dates_order

  scope :active, -> { where(active: true) }

  private

  def parts_sum_matches_total
    return if questions_total.blank? || basic_questions_count.blank? || specialist_questions_count.blank?
    return if questions_total == basic_questions_count + specialist_questions_count

    errors.add(:questions_total, "must equal basic + specialist question counts")
  end

  def pass_score_not_above_max_score
    return if pass_score.blank? || max_score.blank?
    return if pass_score <= max_score

    errors.add(:pass_score, "must not exceed max score")
  end

  def effective_dates_order
    return if effective_from.blank? || effective_to.blank?
    return if effective_to >= effective_from

    errors.add(:effective_to, "must be on or after effective_from")
  end
end
