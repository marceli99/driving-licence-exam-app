# frozen_string_literal: true

class MediaAsset < ApplicationRecord
  has_one_attached :original_file
  has_one_attached :web_file

  has_many :question_media_links, dependent: :nullify
  has_many :questions, through: :question_media_links

  enum :kind, { image: 0, video: 1 }, prefix: true
  enum :processing_status, { pending: 0, attached: 1, missing: 2, failed: 3 }, prefix: true

  validates :source_filename, presence: true
  validates :byte_size, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_ms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :width, numericality: { greater_than: 0 }, allow_nil: true
  validates :height, numericality: { greater_than: 0 }, allow_nil: true
end
