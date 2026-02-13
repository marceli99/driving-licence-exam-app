namespace :media do
  desc "Transcode attached WMV files to MP4 web variants and attach as MediaAsset#web_file"
  task :transcode_wmv, [ :limit, :force ] => :environment do |_task, args|
    limit = args[:limit].presence&.to_i || ENV["LIMIT"]&.to_i
    force = ActiveModel::Type::Boolean.new.cast(args[:force].presence || ENV["FORCE"])
    media_root = Pathname(ENV["MEDIA_ROOT"].presence || Rails.root.join("Pytania egzaminacyjne na prawo jazdy 2025"))

    active_bank = QuestionBank.active.order(imported_at: :desc, updated_at: :desc).first
    raise "No active question bank found." if active_bank.nil?

    scope = MediaAsset.kind_video
      .joins(:original_file_attachment)
      .joins(question_media_links: :question)
      .where(question_media_links: { status: QuestionMediaLink.statuses.fetch("attached") })
      .where(questions: { question_bank_id: active_bank.id, active: true })
      .where("LOWER(media_assets.source_filename) LIKE ?", "%.wmv")
      .distinct

    asset_ids = scope.order("media_assets.id ASC").pluck("media_assets.id")
    asset_ids = asset_ids.first(limit) if limit.present? && limit > 0
    total = asset_ids.size

    puts "Starting WMV -> MP4 transcode for #{total} media assets in active bank #{active_bank.identifier} (force=#{force})..."

    converted = 0
    skipped = 0
    failed = 0
    started_at = Time.current

    asset_ids.each do |asset_id|
      asset = MediaAsset.find(asset_id)
      begin
        result = MediaVideoTranscoder.new(asset, force: force).call
        if result == :converted
          converted += 1
        else
          skipped += 1
        end
      rescue ActiveStorage::FileNotFoundError
        source_path = media_root.join(asset.source_filename.to_s)
        if source_path.file?
          asset.original_file.purge if asset.original_file.attached?
          File.open(source_path, "rb") do |io|
            asset.original_file.attach(
              io: io,
              filename: File.basename(source_path),
              content_type: Marcel::MimeType.for(source_path, name: File.basename(source_path))
            )
          end

          retry_result = MediaVideoTranscoder.new(asset, force: true).call
          if retry_result == :converted
            converted += 1
            puts "RECOVERED asset_id=#{asset.id} source=#{asset.source_filename.inspect}"
          else
            skipped += 1
          end
        else
          failed += 1
          metadata = asset.metadata.dup
          metadata["web_variant_error"] = "original_file_missing"
          asset.update_columns(
            processing_status: MediaAsset.processing_statuses.fetch("missing"),
            metadata: metadata,
            updated_at: Time.current
          )
          puts "FAILED asset_id=#{asset.id} source=#{asset.source_filename.inspect} error=original file missing in Active Storage and source file not found"
        end
      rescue StandardError => e
        failed += 1
        puts "FAILED asset_id=#{asset.id} source=#{asset.source_filename.inspect} error=#{e.message}"
      end

      processed = converted + skipped + failed
      if (processed % 25).zero? || processed == total
        elapsed = (Time.current - started_at).round(1)
        puts "Progress: #{processed}/#{total} converted=#{converted} skipped=#{skipped} failed=#{failed} elapsed=#{elapsed}s"
      end
    end

    elapsed = (Time.current - started_at).round(1)
    puts "Done. total=#{total} converted=#{converted} skipped=#{skipped} failed=#{failed} elapsed=#{elapsed}s"
  end
end
