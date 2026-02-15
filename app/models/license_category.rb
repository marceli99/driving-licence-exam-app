# frozen_string_literal: true

class LicenseCategory < ApplicationRecord
  has_many :question_categories, dependent: :destroy
  has_many :questions, through: :question_categories
  has_many :exam_attempts, dependent: :nullify

  validates :code, presence: true, uniqueness: true, format: { with: /\A[A-Z0-9]+\z/ }

  scope :active, -> { where(active: true) }
end
