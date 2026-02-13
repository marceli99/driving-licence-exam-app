class QuestionCategory < ApplicationRecord
  belongs_to :question
  belongs_to :license_category

  validates :license_category_id, uniqueness: { scope: :question_id }
end
