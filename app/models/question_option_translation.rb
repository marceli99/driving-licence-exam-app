class QuestionOptionTranslation < ApplicationRecord
  belongs_to :question_option

  validates :locale, presence: true, inclusion: { in: DrivingTestConstants::LOCALES }
  validates :text, presence: true
  validates :locale, uniqueness: { scope: :question_option_id }
end
