def seed_defaults!
  %w[AM A1 A2 A B1 B C1 C D1 D T PT].each do |code|
    LicenseCategory.find_or_create_by!(code: code) do |category|
      category.name = code
      category.active = true
    end
  end

  blueprint = ExamBlueprint.find_or_create_by!(name: "Official Theory Exam (PL)") do |exam_blueprint|
    exam_blueprint.description = "Default official-style distribution for Polish theory test."
    exam_blueprint.active = true
    exam_blueprint.questions_total = 32
    exam_blueprint.basic_questions_count = 20
    exam_blueprint.specialist_questions_count = 12
    exam_blueprint.duration_minutes = 25
    exam_blueprint.pass_score = 68
    exam_blueprint.max_score = 74
  end

  rules = [
    { scope: :basic, question_weight: 3, questions_count: 10 },
    { scope: :basic, question_weight: 2, questions_count: 6 },
    { scope: :basic, question_weight: 1, questions_count: 4 },
    { scope: :specialist, question_weight: 3, questions_count: 6 },
    { scope: :specialist, question_weight: 2, questions_count: 4 },
    { scope: :specialist, question_weight: 1, questions_count: 2 }
  ]

  rules.each do |rule|
    record = blueprint.exam_blueprint_rules.find_or_initialize_by(
      scope: ExamBlueprintRule.scopes.fetch(rule[:scope].to_s),
      question_weight: rule[:question_weight]
    )
    record.questions_count = rule[:questions_count]
    record.save!
  end
end

snapshot_path = Pathname(ENV["SNAPSHOT_PATH"].presence || Rails.root.join("db/seeds/full_snapshot.json.gz"))

if snapshot_path.file?
  require_relative "seeds/full_snapshot_loader"
  SeedSnapshots::Loader.import!(snapshot_path, force: ActiveModel::Type::Boolean.new.cast(ENV.fetch("FORCE", "false")))
else
  seed_defaults!
end
