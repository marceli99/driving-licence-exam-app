# frozen_string_literal: true

class QuestionBank < ApplicationRecord
  has_many :questions, dependent: :destroy
  has_many :exam_attempts, dependent: :restrict_with_exception

  validates :identifier, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
end
