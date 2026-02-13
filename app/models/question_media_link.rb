class QuestionMediaLink < ApplicationRecord
  belongs_to :question
  belongs_to :media_asset, optional: true

  enum :slot, {
    main: 0,
    pjm_question: 1,
    pjm_answer_a: 2,
    pjm_answer_b: 3,
    pjm_answer_c: 4
  }, prefix: true

  enum :status, { pending: 0, attached: 1, missing: 2 }, prefix: true

  validates :source_filename, presence: true
  validates :slot, uniqueness: { scope: :question_id }
end
