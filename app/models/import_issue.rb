class ImportIssue < ApplicationRecord
  belongs_to :import_run

  enum :severity, { warning: 0, error: 1 }, prefix: true

  validates :code, presence: true
  validates :message, presence: true
  validates :row_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
