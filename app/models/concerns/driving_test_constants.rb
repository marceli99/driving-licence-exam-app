module DrivingTestConstants
  LOCALES = %w[pl en de ua].freeze
  ANSWER_KEYS = %w[T N A B C].freeze
  YES_NO_KEYS = %w[T N].freeze
  SINGLE_CHOICE_KEYS = %w[A B C].freeze
  QUESTION_WEIGHTS = [ 1, 2, 3 ].freeze
  BASIC_QUESTION_TIME_LIMIT_SECONDS = 35
  SPECIALIST_QUESTION_TIME_LIMIT_SECONDS = 50
end
