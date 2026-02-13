namespace :questions do
  desc "Import question bank from XLSX and media directory"
  task :import, [ :xlsx, :media_root, :identifier, :published_on, :replace_existing, :activate ] => :environment do |_task, args|
    xlsx = args[:xlsx] || ENV["XLSX_PATH"]
    media_root = args[:media_root] || ENV["MEDIA_ROOT"]
    identifier = args[:identifier] || ENV["QUESTION_BANK_ID"] || Time.current.strftime("%m%Y")
    published_on = args[:published_on] || ENV["PUBLISHED_ON"]
    replace_existing = args[:replace_existing].presence || ENV["REPLACE_EXISTING"] || "true"
    activate = args[:activate].presence || ENV["ACTIVATE"] || "true"

    if xlsx.blank? || media_root.blank?
      raise ArgumentError, "Provide xlsx and media_root arguments, e.g. bin/rails 'questions:import[path.xlsx,media_dir,122025]'"
    end

    importer = QuestionBankImporter.new(
      xlsx_path: xlsx,
      media_root: media_root,
      identifier: identifier,
      published_on: published_on,
      replace_existing: ActiveModel::Type::Boolean.new.cast(replace_existing),
      activate: ActiveModel::Type::Boolean.new.cast(activate)
    )

    question_bank = importer.call
    run = ImportRun.where(question_bank: question_bank).order(created_at: :desc).first

    puts "Question bank imported: #{question_bank.identifier} (id=#{question_bank.id})"
    puts "Import run status: #{run.status}"
    puts "Rows total/imported/skipped: #{run.total_rows}/#{run.imported_rows}/#{run.skipped_rows}"
    puts "Warnings/errors: #{run.warning_count}/#{run.error_count}"
  end
end
