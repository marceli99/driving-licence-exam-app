# frozen_string_literal: true

class QuestionTranslation < ApplicationRecord
  belongs_to :question

  validates :locale, presence: true, inclusion: { in: DrivingTestConstants::LOCALES }
  validates :stem, presence: true
  validates :locale, uniqueness: { scope: :question_id }
end
