class Question < ApplicationRecord
  belongs_to :question_bank

  has_many :question_translations, dependent: :destroy
  has_many :question_options, dependent: :destroy
  has_many :question_categories, dependent: :destroy
  has_many :license_categories, through: :question_categories
  has_many :question_media_links, dependent: :destroy
  has_many :media_assets, through: :question_media_links
  has_many :exam_attempt_items, dependent: :restrict_with_exception

  enum :scope, { basic: 0, specialist: 1 }, prefix: true
  enum :answer_mode, { yes_no: 0, single_choice: 1 }, prefix: true

  validates :official_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :source_lp, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :source_row, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :correct_key, presence: true, inclusion: { in: DrivingTestConstants::ANSWER_KEYS }
  validates :question_weight, inclusion: { in: DrivingTestConstants::QUESTION_WEIGHTS }, allow_nil: true
  validate :correct_key_matches_answer_mode

  scope :enabled, -> { where(active: true) }

  def stem_for(locale)
    translation_for(locale)&.stem || translation_for("pl")&.stem || question_translations.first&.stem.to_s
  end

  def translation_for(locale)
    question_translations.find { |translation| translation.locale == locale.to_s }
  end

  def media_link_for(slot)
    question_media_links.find { |link| link.slot == slot.to_s }
  end

  private

  def correct_key_matches_answer_mode
    return if correct_key.blank? || answer_mode.blank?

    valid =
      if answer_mode_yes_no?
        DrivingTestConstants::YES_NO_KEYS.include?(correct_key)
      else
        DrivingTestConstants::SINGLE_CHOICE_KEYS.include?(correct_key)
      end

    return if valid

    errors.add(:correct_key, "must match question answer mode")
  end
end
