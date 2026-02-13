class CreateDrivingTestSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :question_banks do |t|
      t.string :identifier, null: false
      t.string :source_filename
      t.string :source_checksum
      t.date :published_on
      t.datetime :imported_at
      t.boolean :active, null: false, default: false
      t.text :notes
      t.timestamps
    end
    add_index :question_banks, :identifier, unique: true

    create_table :license_categories do |t|
      t.string :code, null: false
      t.string :name
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :license_categories, :code, unique: true

    create_table :exam_blueprints do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :questions_total, null: false, default: 32
      t.integer :basic_questions_count, null: false, default: 20
      t.integer :specialist_questions_count, null: false, default: 12
      t.integer :duration_minutes, null: false, default: 25
      t.integer :pass_score, null: false, default: 68
      t.integer :max_score, null: false, default: 74
      t.date :effective_from
      t.date :effective_to
      t.timestamps
    end
    add_index :exam_blueprints, :name, unique: true

    create_table :questions do |t|
      t.references :question_bank, null: false, foreign_key: true
      t.integer :official_number, null: false
      t.integer :source_lp
      t.integer :source_row
      t.integer :scope, null: false
      t.integer :answer_mode, null: false
      t.string :correct_key, null: false, limit: 1
      t.integer :question_weight
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :questions, [ :question_bank_id, :official_number ], unique: true
    add_index :questions, [ :scope, :question_weight, :active ]
    add_index :questions, :source_row

    create_table :question_translations do |t|
      t.references :question, null: false, foreign_key: true
      t.string :locale, null: false, limit: 5
      t.text :stem, null: false
      t.timestamps
    end
    add_index :question_translations, [ :question_id, :locale ], unique: true

    create_table :question_options do |t|
      t.references :question, null: false, foreign_key: true
      t.string :key, null: false, limit: 1
      t.integer :position, null: false
      t.timestamps
    end
    add_index :question_options, [ :question_id, :key ], unique: true
    add_index :question_options, [ :question_id, :position ], unique: true

    create_table :question_option_translations do |t|
      t.references :question_option, null: false, foreign_key: true
      t.string :locale, null: false, limit: 5
      t.text :text, null: false
      t.timestamps
    end
    add_index :question_option_translations, [ :question_option_id, :locale ], unique: true

    create_table :question_categories do |t|
      t.references :question, null: false, foreign_key: true
      t.references :license_category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :question_categories, [ :question_id, :license_category_id ], unique: true

    create_table :media_assets do |t|
      t.integer :kind, null: false
      t.string :source_filename, null: false
      t.string :normalized_filename
      t.string :checksum_sha256
      t.string :content_type
      t.bigint :byte_size
      t.integer :duration_ms
      t.integer :width
      t.integer :height
      t.integer :processing_status, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :media_assets, :source_filename
    add_index :media_assets, :normalized_filename
    add_index :media_assets, :checksum_sha256

    create_table :question_media_links do |t|
      t.references :question, null: false, foreign_key: true
      t.references :media_asset, foreign_key: true
      t.integer :slot, null: false
      t.string :source_filename, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end
    add_index :question_media_links, [ :question_id, :slot ], unique: true
    add_index :question_media_links, :source_filename
    add_index :question_media_links, [ :media_asset_id, :slot ]

    create_table :exam_blueprint_rules do |t|
      t.references :exam_blueprint, null: false, foreign_key: true
      t.integer :scope, null: false
      t.integer :question_weight, null: false
      t.integer :questions_count, null: false
      t.timestamps
    end
    add_index :exam_blueprint_rules, [ :exam_blueprint_id, :scope, :question_weight ], unique: true

    create_table :exam_attempts do |t|
      t.references :exam_blueprint, null: false, foreign_key: true
      t.references :question_bank, null: false, foreign_key: true
      t.references :license_category, foreign_key: true
      t.string :locale, null: false, default: "pl", limit: 5
      t.integer :status, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :deadline_at, null: false
      t.datetime :submitted_at
      t.integer :score
      t.integer :max_score, null: false, default: 74
      t.boolean :passed
      t.bigint :random_seed
      t.timestamps
    end
    add_index :exam_attempts, :status
    add_index :exam_attempts, :started_at

    create_table :exam_attempt_items do |t|
      t.references :exam_attempt, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :points_possible, null: false
      t.string :selected_key, limit: 1
      t.string :correct_key, null: false, limit: 1
      t.boolean :answered_correctly
      t.datetime :answered_at
      t.jsonb :snapshot, null: false, default: {}
      t.timestamps
    end
    add_index :exam_attempt_items, [ :exam_attempt_id, :position ], unique: true
    add_index :exam_attempt_items, [ :exam_attempt_id, :question_id ], unique: true
    add_index :exam_attempt_items, [ :exam_attempt_id, :answered_correctly ]

    create_table :import_runs do |t|
      t.references :question_bank, foreign_key: true
      t.string :source_filename, null: false
      t.string :source_checksum
      t.integer :status, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :total_rows, null: false, default: 0
      t.integer :imported_rows, null: false, default: 0
      t.integer :skipped_rows, null: false, default: 0
      t.integer :warning_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.text :summary
      t.timestamps
    end
    add_index :import_runs, :status
    add_index :import_runs, :started_at

    create_table :import_issues do |t|
      t.references :import_run, null: false, foreign_key: true
      t.integer :severity, null: false
      t.integer :row_number
      t.string :code, null: false
      t.text :message, null: false
      t.jsonb :context, null: false, default: {}
      t.timestamps
    end
    add_index :import_issues, [ :import_run_id, :severity ]
    add_index :import_issues, :code

    add_check_constraint :questions, "scope IN (0, 1)", name: "questions_scope_valid"
    add_check_constraint :questions, "answer_mode IN (0, 1)", name: "questions_answer_mode_valid"
    add_check_constraint :questions, "correct_key IN ('T', 'N', 'A', 'B', 'C')", name: "questions_correct_key_valid"
    add_check_constraint :questions, "question_weight IS NULL OR question_weight IN (1, 2, 3)", name: "questions_weight_valid"
    add_check_constraint :questions, "(answer_mode = 0 AND correct_key IN ('T', 'N')) OR (answer_mode = 1 AND correct_key IN ('A', 'B', 'C'))", name: "questions_correct_key_matches_mode"

    add_check_constraint :question_translations, "locale IN ('pl', 'en', 'de', 'ua')", name: "question_translations_locale_valid"
    add_check_constraint :question_option_translations, "locale IN ('pl', 'en', 'de', 'ua')", name: "question_option_translations_locale_valid"
    add_check_constraint :exam_attempts, "locale IN ('pl', 'en', 'de', 'ua')", name: "exam_attempts_locale_valid"

    add_check_constraint :question_options, "key IN ('A', 'B', 'C')", name: "question_options_key_valid"
    add_check_constraint :question_options, "position BETWEEN 1 AND 3", name: "question_options_position_valid"

    add_check_constraint :media_assets, "kind IN (0, 1)", name: "media_assets_kind_valid"
    add_check_constraint :media_assets, "processing_status IN (0, 1, 2, 3)", name: "media_assets_processing_status_valid"
    add_check_constraint :media_assets, "byte_size IS NULL OR byte_size >= 0", name: "media_assets_byte_size_non_negative"
    add_check_constraint :media_assets, "duration_ms IS NULL OR duration_ms >= 0", name: "media_assets_duration_non_negative"
    add_check_constraint :media_assets, "width IS NULL OR width > 0", name: "media_assets_width_positive"
    add_check_constraint :media_assets, "height IS NULL OR height > 0", name: "media_assets_height_positive"

    add_check_constraint :question_media_links, "slot IN (0, 1, 2, 3, 4)", name: "question_media_links_slot_valid"
    add_check_constraint :question_media_links, "status IN (0, 1, 2)", name: "question_media_links_status_valid"

    add_check_constraint :exam_blueprints, "questions_total > 0", name: "exam_blueprints_questions_total_positive"
    add_check_constraint :exam_blueprints, "basic_questions_count > 0", name: "exam_blueprints_basic_count_positive"
    add_check_constraint :exam_blueprints, "specialist_questions_count > 0", name: "exam_blueprints_specialist_count_positive"
    add_check_constraint :exam_blueprints, "duration_minutes > 0", name: "exam_blueprints_duration_positive"
    add_check_constraint :exam_blueprints, "pass_score > 0", name: "exam_blueprints_pass_score_positive"
    add_check_constraint :exam_blueprints, "max_score > 0", name: "exam_blueprints_max_score_positive"
    add_check_constraint :exam_blueprints, "pass_score <= max_score", name: "exam_blueprints_pass_not_above_max"
    add_check_constraint :exam_blueprints, "questions_total = basic_questions_count + specialist_questions_count", name: "exam_blueprints_total_matches_parts"
    add_check_constraint :exam_blueprints, "effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from", name: "exam_blueprints_effective_dates_order"

    add_check_constraint :exam_blueprint_rules, "scope IN (0, 1)", name: "exam_blueprint_rules_scope_valid"
    add_check_constraint :exam_blueprint_rules, "question_weight IN (1, 2, 3)", name: "exam_blueprint_rules_weight_valid"
    add_check_constraint :exam_blueprint_rules, "questions_count > 0", name: "exam_blueprint_rules_questions_count_positive"

    add_check_constraint :exam_attempts, "status IN (0, 1, 2, 3)", name: "exam_attempts_status_valid"
    add_check_constraint :exam_attempts, "max_score > 0", name: "exam_attempts_max_score_positive"
    add_check_constraint :exam_attempts, "score IS NULL OR (score >= 0 AND score <= max_score)", name: "exam_attempts_score_valid_range"
    add_check_constraint :exam_attempts, "deadline_at >= started_at", name: "exam_attempts_deadline_after_start"

    add_check_constraint :exam_attempt_items, "position > 0", name: "exam_attempt_items_position_positive"
    add_check_constraint :exam_attempt_items, "points_possible IN (1, 2, 3)", name: "exam_attempt_items_points_possible_valid"
    add_check_constraint :exam_attempt_items, "selected_key IS NULL OR selected_key IN ('T', 'N', 'A', 'B', 'C')", name: "exam_attempt_items_selected_key_valid"
    add_check_constraint :exam_attempt_items, "correct_key IN ('T', 'N', 'A', 'B', 'C')", name: "exam_attempt_items_correct_key_valid"

    add_check_constraint :import_runs, "status IN (0, 1, 2, 3)", name: "import_runs_status_valid"
    add_check_constraint :import_runs, "total_rows >= 0", name: "import_runs_total_rows_non_negative"
    add_check_constraint :import_runs, "imported_rows >= 0", name: "import_runs_imported_rows_non_negative"
    add_check_constraint :import_runs, "skipped_rows >= 0", name: "import_runs_skipped_rows_non_negative"
    add_check_constraint :import_runs, "warning_count >= 0", name: "import_runs_warning_count_non_negative"
    add_check_constraint :import_runs, "error_count >= 0", name: "import_runs_error_count_non_negative"
    add_check_constraint :import_runs, "finished_at IS NULL OR finished_at >= started_at", name: "import_runs_finished_after_start"

    add_check_constraint :import_issues, "severity IN (0, 1)", name: "import_issues_severity_valid"
    add_check_constraint :import_issues, "row_number IS NULL OR row_number > 0", name: "import_issues_row_number_positive"
  end
end
