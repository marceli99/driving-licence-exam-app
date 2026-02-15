# frozen_string_literal: true

class ExamAttemptsController < ApplicationController
  before_action :set_reference_data, only: %i[new create]
  before_action :set_exam_attempt, only: %i[show update cancel result]
  before_action :expire_exam_attempt_if_needed, only: %i[show update]

  def show
    unless @exam_attempt.status_in_progress?
      redirect_to result_exam_attempt_path(@exam_attempt)
      return
    end

    now = Time.current
    return if advance_if_current_question_timed_out?(now)

    @current_item = current_exam_item
    if @current_item.nil?
      submit_exam_attempt!(now)
      redirect_to result_exam_attempt_path(@exam_attempt)
      return
    end

    ensure_question_presented!(@current_item, now)

    @questions_total = @exam_attempt.exam_attempt_items.count
    @answered_questions_count = @questions_total - unanswered_items_count
    @last_question = unanswered_items_count == 1
    @exam_time_left_seconds = [(@exam_attempt.deadline_at - now).to_i, 0].max
    @question_time_limit_seconds = question_time_limit_seconds(@current_item)
    @question_time_left_seconds = question_time_left_seconds(@current_item, now)
  end

  def new
    @selected_locale = normalized_locale(params[:locale].presence || 'pl')
    @selected_category_id = params[:license_category_id]
  end

  def create
    @selected_locale = normalized_locale(attempt_params[:locale].presence || 'pl')
    @selected_category_id = attempt_params[:license_category_id]

    license_category = @license_categories.find_by(id: @selected_category_id)
    builder = ExamAttemptBuilder.new(
      license_category: license_category,
      locale: @selected_locale,
      exam_blueprint: @exam_blueprint,
      question_bank: @question_bank
    )

    attempt = builder.call
    redirect_to exam_attempt_path(attempt)
  rescue ExamAttemptBuilder::BuildError => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_content
  end

  def update
    unless @exam_attempt.status_in_progress?
      redirect_to result_exam_attempt_path(@exam_attempt)
      return
    end

    now = Time.current
    item = current_exam_item
    if item.nil?
      submit_exam_attempt!(now)
      redirect_to result_exam_attempt_path(@exam_attempt)
      return
    end

    ensure_question_presented!(item, now)

    if params[:item_id].to_i != item.id
      redirect_to exam_attempt_path(@exam_attempt), alert: t('ui.flash.question_already_closed')
      return
    end

    selected_key = question_timed_out?(item, now) ? nil : sanitize_answer_key(item, params[:answer])
    answered_correctly = selected_key.present? && selected_key == item.correct_key

    item.update!(
      selected_key: selected_key,
      answered_at: now,
      answered_correctly: answered_correctly
    )

    @current_exam_item = nil
    if current_exam_item.nil?
      submit_exam_attempt!(now)
      redirect_to result_exam_attempt_path(@exam_attempt)
      return
    end

    redirect_to exam_attempt_path(@exam_attempt)
  end

  def result
    if @exam_attempt.status_in_progress?
      redirect_to exam_attempt_path(@exam_attempt)
      return
    end

    @items = exam_items_for_view
  end

  def cancel
    unless @exam_attempt.status_in_progress?
      redirect_to root_path, notice: t('ui.flash.exam_already_finished')
      return
    end

    @exam_attempt.update!(
      status: :cancelled,
      submitted_at: Time.current,
      score: @exam_attempt.exam_attempt_items.where(answered_correctly: true).sum(:points_possible),
      passed: false
    )

    redirect_to root_path, notice: t('ui.flash.exam_cancelled')
  end

  private

  def set_reference_data
    @question_bank = QuestionBank.active.order(imported_at: :desc, updated_at: :desc).first
    @exam_blueprint = ExamBlueprint.active.order(updated_at: :desc).first
    @license_categories = LicenseCategory.active.order(:code)
  end

  def set_exam_attempt
    @exam_attempt = ExamAttempt.find_by!(uuid: params[:uuid])
  end

  def attempt_params
    params.permit(:license_category_id, :locale)
  end

  def normalized_locale(locale)
    value = locale.to_s
    return value if DrivingTestConstants::LOCALES.include?(value)

    'pl'
  end

  def exam_items_for_view
    @exam_attempt.exam_attempt_items
                 .includes(question: [
                             :question_translations,
                             { question_options: :question_option_translations },
                             { question_media_links: { media_asset: %i[original_file_attachment original_file_blob] } }
                           ])
                 .order(:position)
  end

  def current_exam_item
    @current_exam_item ||= @exam_attempt.exam_attempt_items
                                        .includes(question: [
                                                    :question_translations,
                                                    { question_options: :question_option_translations },
                                                    { question_media_links: { media_asset: %i[original_file_attachment
                                                                                              original_file_blob] } }
                                                  ])
                                        .where(answered_at: nil)
                                        .order(:position)
                                        .first
  end

  def unanswered_items_count
    @unanswered_items_count ||= @exam_attempt.exam_attempt_items.where(answered_at: nil).count
  end

  def ensure_question_presented!(item, now)
    return if item.blank?
    return if item.snapshot['presented_at'].present?

    item.update!(snapshot: item.snapshot.merge('presented_at' => now.iso8601))
  end

  def presented_at_for(item)
    raw = item.snapshot['presented_at']
    return item.created_at if raw.blank?

    Time.zone.parse(raw) || item.created_at
  rescue ArgumentError
    item.created_at
  end

  def question_time_limit_seconds(item)
    if item.question.scope_basic?
      DrivingTestConstants::BASIC_QUESTION_TIME_LIMIT_SECONDS
    else
      DrivingTestConstants::SPECIALIST_QUESTION_TIME_LIMIT_SECONDS
    end
  end

  def question_time_left_seconds(item, now)
    deadline = presented_at_for(item) + question_time_limit_seconds(item).seconds
    [(deadline - now).to_i, 0].max
  end

  def question_timed_out?(item, now)
    question_time_left_seconds(item, now).zero?
  end

  def sanitize_answer_key(item, key)
    answer = key.to_s.upcase.presence
    return nil if answer.blank?

    valid_keys =
      if item.question.answer_mode_yes_no?
        DrivingTestConstants::YES_NO_KEYS
      else
        DrivingTestConstants::SINGLE_CHOICE_KEYS
      end

    valid_keys.include?(answer) ? answer : nil
  end

  def advance_if_current_question_timed_out?(now)
    item = current_exam_item
    return false if item.nil?

    ensure_question_presented!(item, now)
    return false unless question_timed_out?(item, now)

    item.update!(selected_key: nil, answered_at: now, answered_correctly: false)
    @current_exam_item = nil

    if current_exam_item.nil?
      submit_exam_attempt!(now)
      redirect_to result_exam_attempt_path(@exam_attempt)
    else
      redirect_to exam_attempt_path(@exam_attempt)
    end

    true
  end

  def submit_exam_attempt!(submitted_at)
    score = @exam_attempt.exam_attempt_items.where(answered_correctly: true).sum(:points_possible)
    @exam_attempt.update!(
      status: :submitted,
      submitted_at: submitted_at,
      score: score,
      passed: score >= @exam_attempt.exam_blueprint.pass_score
    )
  end

  def expire_exam_attempt_if_needed
    return unless @exam_attempt.status_in_progress?
    return if Time.current <= @exam_attempt.deadline_at

    score = @exam_attempt.exam_attempt_items.where(answered_correctly: true).sum(:points_possible)
    @exam_attempt.update!(
      status: :expired,
      submitted_at: Time.current,
      score: score,
      passed: score >= @exam_attempt.exam_blueprint.pass_score
    )
  end
end
