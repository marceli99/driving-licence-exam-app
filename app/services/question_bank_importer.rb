require "digest"
require "stringio"

class QuestionBankImporter
  SCOPE_MAP = {
    "PODSTAWOWY" => :basic,
    "SPECJALISTYCZNY" => :specialist
  }.freeze

  LOCALE_COLUMNS = {
    "pl" => { stem: "C", options: { "A" => "D", "B" => "E", "C" => "F" } },
    "en" => { stem: "O", options: { "A" => "P", "B" => "Q", "C" => "R" } },
    "de" => { stem: "S", options: { "A" => "T", "B" => "U", "C" => "V" } },
    "ua" => { stem: "W", options: { "A" => "X", "B" => "Y", "C" => "Z" } }
  }.freeze

  MEDIA_COLUMNS = {
    main: "H",
    pjm_question: "K",
    pjm_answer_a: "L",
    pjm_answer_b: "M",
    pjm_answer_c: "N"
  }.freeze

  def initialize(xlsx_path:, media_root:, identifier:, published_on: nil, replace_existing: true, activate: true)
    @xlsx_path = Pathname(xlsx_path)
    @media_root = Pathname(media_root)
    @identifier = identifier.to_s.strip
    @published_on = published_on.presence
    @replace_existing = replace_existing
    @activate = activate

    @warning_count = 0
    @error_count = 0
    @imported_rows = 0
    @skipped_rows = 0
    @total_rows = 0
    @category_cache = {}
    @media_cache = {}
  end

  def call
    validate_input!

    @import_run = ImportRun.create!(
      source_filename: @xlsx_path.basename.to_s,
      source_checksum: Digest::SHA256.file(@xlsx_path).hexdigest,
      status: :running,
      started_at: Time.current
    )

    @question_bank = prepare_question_bank!
    @import_run.update!(question_bank: @question_bank)

    @media_resolver = MediaFileResolver.new(@media_root)
    reader = SimpleXlsxReader.new(@xlsx_path)

    reader.each_row do |row|
      next if row.number == 1

      @total_rows += 1
      import_single_row(row)
    end

    finalize_import_run!
    @question_bank
  rescue StandardError => e
    fail_import_run!(e)
    raise
  end

  private

  def validate_input!
    raise ArgumentError, "identifier cannot be blank" if @identifier.blank?
    raise ArgumentError, "XLSX file not found: #{@xlsx_path}" unless @xlsx_path.file?
    raise ArgumentError, "Media directory not found: #{@media_root}" unless @media_root.directory?
  end

  def prepare_question_bank!
    question_bank = QuestionBank.find_or_initialize_by(identifier: @identifier)

    if question_bank.persisted? && @replace_existing
      if question_bank.exam_attempts.exists?
        raise "Cannot replace question bank #{@identifier} because exam attempts are linked to it"
      end

      question_bank.questions.find_each(&:destroy!)
    end

    question_bank.assign_attributes(
      source_filename: @xlsx_path.basename.to_s,
      source_checksum: Digest::SHA256.file(@xlsx_path).hexdigest,
      imported_at: Time.current,
      published_on: @published_on,
      active: @activate
    )
    question_bank.save!

    QuestionBank.where.not(id: question_bank.id).where(active: true).update_all(active: false) if @activate

    question_bank
  end

  def import_single_row(row)
    ActiveRecord::Base.transaction(requires_new: true) do
      import_row_in_transaction(row)
    rescue StandardError => e
      @skipped_rows += 1
      @error_count += 1
      create_issue(
        severity: :error,
        row_number: row.number,
        code: "row_import_failed",
        message: e.message,
        context: { backtrace: e.backtrace&.first(3) }
      )
    end
  end

  def import_row_in_transaction(row)
    cells = row.cells

    official_number = parse_integer(cells["B"])
    raise "Missing or invalid official question number" if official_number.nil?

    scope = parse_scope(cells["I"])
    raise "Unknown scope value '#{cells['I']}'" if scope.nil?

    correct_key = cells["G"].to_s.strip.upcase
    unless DrivingTestConstants::ANSWER_KEYS.include?(correct_key)
      raise "Invalid correct answer key '#{correct_key}'"
    end

    answer_mode = infer_answer_mode(cells, correct_key, row.number)
    question = build_or_update_question(row, cells, official_number, scope, answer_mode, correct_key)

    persist_question_translations!(question, cells, row.number)
    persist_question_options!(question, cells, row.number)
    persist_categories!(question, cells, row.number)
    persist_media_links!(question, cells, row.number)

    @imported_rows += 1
  end

  def build_or_update_question(row, cells, official_number, scope, answer_mode, correct_key)
    question = @question_bank.questions.find_or_initialize_by(official_number: official_number)

    if question.persisted?
      question.question_translations.delete_all
      question.question_options.find_each(&:destroy!)
      question.question_categories.delete_all
      question.question_media_links.delete_all
    end

    question.assign_attributes(
      source_lp: parse_integer(cells["A"]),
      source_row: row.number,
      scope: scope,
      answer_mode: answer_mode,
      correct_key: correct_key,
      question_weight: nil,
      active: true
    )
    question.save!
    question
  end

  def persist_question_translations!(question, cells, row_number)
    pl_stem = cells[LOCALE_COLUMNS.fetch("pl").fetch(:stem)].to_s.strip
    if pl_stem.blank?
      raise "Missing Polish question text"
    end

    LOCALE_COLUMNS.each do |locale, mapping|
      stem = cells[mapping.fetch(:stem)].to_s.strip
      next if stem.blank?

      question.question_translations.create!(
        locale: locale,
        stem: stem
      )
    end
  rescue StandardError => e
    raise "#{e.message} (row #{row_number})"
  end

  def persist_question_options!(question, cells, row_number)
    return if question.answer_mode_yes_no?

    option_texts = {
      "A" => cells["D"].to_s.strip,
      "B" => cells["E"].to_s.strip,
      "C" => cells["F"].to_s.strip
    }

    if option_texts.values.any?(&:blank?)
      @warning_count += 1
      create_issue(
        severity: :warning,
        row_number: row_number,
        code: "single_choice_missing_option_text",
        message: "Single choice question has blank option text in PL",
        context: option_texts
      )
    end

    %w[A B C].each_with_index do |key, index|
      option = question.question_options.create!(key: key, position: index + 1)

      LOCALE_COLUMNS.each do |locale, mapping|
        column = mapping.fetch(:options).fetch(key)
        text = cells[column].to_s.strip
        next if text.blank?

        option.question_option_translations.create!(locale: locale, text: text)
      end
    end
  rescue StandardError => e
    raise "#{e.message} (row #{row_number})"
  end

  def persist_categories!(question, cells, row_number)
    categories = cells["J"].to_s.split(",").map { |item| item.strip.upcase }.reject(&:blank?).uniq
    if categories.empty?
      @warning_count += 1
      create_issue(
        severity: :warning,
        row_number: row_number,
        code: "missing_categories",
        message: "Question has no category mapping",
        context: {}
      )
      return
    end

    categories.each do |code|
      category = @category_cache[code] ||= LicenseCategory.find_or_create_by!(code: code) do |record|
        record.name = code
        record.active = true
      end

      question.question_categories.find_or_create_by!(license_category: category)
    end
  end

  def persist_media_links!(question, cells, row_number)
    MEDIA_COLUMNS.each do |slot, column|
      source_filename = cells[column].to_s.strip
      next if source_filename.blank?

      resolution = @media_resolver.resolve(source_filename)
      media_asset = fetch_media_asset(source_filename, resolution, row_number)
      status = resolution.found? ? :attached : :missing

      question.question_media_links.create!(
        slot: slot,
        source_filename: source_filename,
        media_asset: media_asset,
        status: status
      )

      if resolution.status == :ambiguous
        @warning_count += 1
        create_issue(
          severity: :warning,
          row_number: row_number,
          code: "media_file_ambiguous",
          message: "Multiple candidate files found for media reference",
          context: { source_filename: source_filename, candidates: resolution.candidates.map { |path| File.basename(path) } }
        )
      elsif resolution.status == :missing
        @warning_count += 1
        create_issue(
          severity: :warning,
          row_number: row_number,
          code: "media_file_missing",
          message: "Media file referenced in XLSX is missing",
          context: { source_filename: source_filename, slot: slot }
        )
      elsif resolution.match_type == :normalized
        @warning_count += 1
        create_issue(
          severity: :warning,
          row_number: row_number,
          code: "media_file_normalized_match",
          message: "Media file matched using normalized filename",
          context: { source_filename: source_filename, resolved_filename: File.basename(resolution.path) }
        )
      end
    end
  end

  def fetch_media_asset(source_filename, resolution, row_number)
    kind = infer_media_kind(source_filename)
    cache_key = "#{kind}:#{source_filename}"
    cached = @media_cache[cache_key]
    return cached if cached

    media_asset = MediaAsset.find_or_initialize_by(source_filename: source_filename, kind: MediaAsset.kinds.fetch(kind.to_s))
    media_asset.normalized_filename = normalize_filename(source_filename)

    if resolution.found?
      attach_media_file!(media_asset, resolution.path, source_filename)
      media_asset.processing_status = :attached
    else
      media_asset.processing_status = :missing
    end

    media_asset.save!
    @media_cache[cache_key] = media_asset
    media_asset
  rescue StandardError => e
    @error_count += 1
    create_issue(
      severity: :error,
      row_number: row_number,
      code: "media_asset_persist_failed",
      message: e.message,
      context: { source_filename: source_filename }
    )
    raise
  end

  def attach_media_file!(media_asset, file_path, source_filename)
    return if media_asset.original_file.attached?

    filename = File.basename(file_path)
    content_type = Marcel::MimeType.for(Pathname(file_path), name: filename)
    checksum = Digest::SHA256.file(file_path).hexdigest

    # Active Storage can upload on transaction commit, so use an in-memory IO to
    # avoid using a file descriptor that may be closed before upload occurs.
    media_asset.original_file.attach(
      io: StringIO.new(File.binread(file_path)),
      filename: filename,
      content_type: content_type
    )

    stat = File.stat(file_path)
    media_asset.byte_size = stat.size
    media_asset.content_type = content_type
    media_asset.checksum_sha256 = checksum
    media_asset.metadata = media_asset.metadata.merge(
      "resolved_filename" => filename,
      "referenced_filename" => source_filename
    )
  end

  def infer_answer_mode(cells, correct_key, row_number)
    values = %w[D E F].map { |column| cells[column].to_s.strip }

    if values.all?(&:blank?)
      return :yes_no
    end

    if values.all?(&:present?)
      return :single_choice
    end

    fallback = DrivingTestConstants::YES_NO_KEYS.include?(correct_key) ? :yes_no : :single_choice
    @warning_count += 1
    create_issue(
      severity: :warning,
      row_number: row_number,
      code: "mixed_answer_format",
      message: "Question has partial option set; fallback mode inferred",
      context: { option_a: values[0], option_b: values[1], option_c: values[2], fallback: fallback, correct_key: correct_key }
    )
    fallback
  end

  def infer_media_kind(filename)
    extension = File.extname(filename).delete(".").downcase
    image_extensions = %w[jpg jpeg png webp gif bmp tif tiff]
    image_extensions.include?(extension) ? :image : :video
  end

  def parse_scope(value)
    SCOPE_MAP[value.to_s.strip.upcase]
  end

  def parse_integer(value)
    stripped = value.to_s.strip
    return nil if stripped.blank?
    return stripped.to_i if stripped.match?(/\A\d+\z/)

    nil
  end

  def normalize_filename(name)
    name
      .to_s
      .unicode_normalize(:nfd)
      .gsub(/\p{Mn}/, "")
      .downcase
      .gsub(/[[:space:]]+/, " ")
      .strip
  end

  def create_issue(severity:, row_number:, code:, message:, context:)
    @import_run.import_issues.create!(
      severity: severity,
      row_number: row_number,
      code: code,
      message: message,
      context: context
    )
  end

  def finalize_import_run!
    final_status =
      if @error_count.zero? && @warning_count.zero?
        :completed
      elsif @error_count.zero?
        :completed_with_warnings
      elsif @imported_rows.positive?
        :completed_with_warnings
      else
        :failed
      end

    @import_run.update!(
      status: final_status,
      finished_at: Time.current,
      total_rows: @total_rows,
      imported_rows: @imported_rows,
      skipped_rows: @skipped_rows,
      warning_count: @warning_count,
      error_count: @error_count,
      summary: import_summary
    )
  end

  def fail_import_run!(exception)
    return unless defined?(@import_run) && @import_run&.persisted?

    @import_run.update!(
      status: :failed,
      finished_at: Time.current,
      total_rows: @total_rows,
      imported_rows: @imported_rows,
      skipped_rows: @skipped_rows,
      warning_count: @warning_count,
      error_count: [ @error_count, 1 ].max,
      summary: "Import aborted: #{exception.class}: #{exception.message}"
    )
  rescue StandardError
    nil
  end

  def import_summary
    "Imported #{@imported_rows}/#{@total_rows} rows, skipped #{@skipped_rows}, warnings #{@warning_count}, errors #{@error_count}"
  end
end
