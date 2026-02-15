# frozen_string_literal: true

class QuestionOption < ApplicationRecord
  belongs_to :question
  has_many :question_option_translations, dependent: :destroy

  validates :key, presence: true, inclusion: { in: %w[A B C] }, uniqueness: { scope: :question_id }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 3 }
  validates :position, uniqueness: { scope: :question_id }

  scope :ordered, -> { order(:position) }

  def text_for(locale)
    translation_for(locale)&.text || translation_for('pl')&.text || question_option_translations.first&.text.to_s
  end

  def translation_for(locale)
    question_option_translations.find { |translation| translation.locale == locale.to_s }
  end
end
