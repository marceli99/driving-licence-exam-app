class ExamAttemptItem < ApplicationRecord
  belongs_to :exam_attempt
  belongs_to :question

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :exam_attempt_id }
  validates :question_id, uniqueness: { scope: :exam_attempt_id }
  validates :points_possible, inclusion: { in: DrivingTestConstants::QUESTION_WEIGHTS }
  validates :selected_key, inclusion: { in: DrivingTestConstants::ANSWER_KEYS }, allow_nil: true
  validates :correct_key, inclusion: { in: DrivingTestConstants::ANSWER_KEYS }
end
