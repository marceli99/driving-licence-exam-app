namespace :media do
  desc "Repair missing question media links by re-scanning media directory"
  task :repair_missing, [ :limit, :dry_run ] => :environment do |_task, args|
    limit = args[:limit].presence&.to_i || ENV["LIMIT"]&.to_i
    dry_run =
      if args.key?(:dry_run)
        ActiveModel::Type::Boolean.new.cast(args[:dry_run])
      else
        ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
      end
    media_root = Pathname(ENV["MEDIA_ROOT"].presence || Rails.root.join("Pytania egzaminacyjne na prawo jazdy 2025"))

    unless media_root.directory?
      raise ArgumentError, "Media directory not found: #{media_root}"
    end

    repairer = MissingMediaRepairer.new(
      media_root: media_root,
      limit: limit,
      dry_run: dry_run
    )

    started_at = Time.current
    result = repairer.call
    elapsed = (Time.current - started_at).round(1)

    puts "media:repair_missing completed (dry_run=#{dry_run}) in #{elapsed}s"
    puts "processed=#{result.processed} repaired=#{result.repaired} already_attached=#{result.already_attached} unresolved=#{result.unresolved} ambiguous=#{result.ambiguous} errors=#{result.errors}"
  end
end
