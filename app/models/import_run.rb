class ImportRun < ApplicationRecord
  belongs_to :question_bank, optional: true
  has_many :import_issues, dependent: :destroy

  enum :status, {
    running: 0,
    completed: 1,
    completed_with_warnings: 2,
    failed: 3
  }, prefix: true

  validates :source_filename, presence: true
  validates :started_at, presence: true
  validates :total_rows, :imported_rows, :skipped_rows, :warning_count, :error_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :finished_not_before_start

  private

  def finished_not_before_start
    return if started_at.blank? || finished_at.blank?
    return if finished_at >= started_at

    errors.add(:finished_at, "must be on or after started_at")
  end
end
