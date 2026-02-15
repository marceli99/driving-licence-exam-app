# frozen_string_literal: true

class ExamBlueprintRule < ApplicationRecord
  belongs_to :exam_blueprint

  enum :scope, { basic: 0, specialist: 1 }, prefix: true

  validates :question_weight, inclusion: { in: DrivingTestConstants::QUESTION_WEIGHTS }
  validates :questions_count, numericality: { only_integer: true, greater_than: 0 }
  validates :question_weight, uniqueness: { scope: %i[exam_blueprint_id scope] }
end
