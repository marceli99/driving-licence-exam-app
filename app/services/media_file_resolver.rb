class MediaFileResolver
  EXTENSION_EQUIVALENTS = {
    "wmv" => %w[mp4 mov avi mkv],
    "mp4" => %w[wmv mov avi mkv],
    "jpg" => %w[jpeg png webp],
    "jpeg" => %w[jpg png webp],
    "png" => %w[jpg jpeg webp]
  }.freeze

  Result = Struct.new(:status, :path, :match_type, :candidates, keyword_init: true) do
    def found?
      status == :found
    end
  end

  def initialize(root_path)
    @root_path = Pathname(root_path)
    @exact_map = {}
    @casefold_map = {}
    @normalized_map = Hash.new { |hash, key| hash[key] = [] }
    @normalized_base_map = Hash.new { |hash, key| hash[key] = [] }
    build_index!
  end

  def resolve(filename)
    return Result.new(status: :missing, path: nil, match_type: :missing, candidates: []) if filename.blank?

    exact = @exact_map[filename]
    return Result.new(status: :found, path: exact, match_type: :exact, candidates: [ exact ]) if exact

    casefold = @casefold_map[filename.downcase]
    return Result.new(status: :found, path: casefold, match_type: :casefold, candidates: [ casefold ]) if casefold

    normalized_key = normalize(filename)
    normalized_candidates = @normalized_map[normalized_key]
    if normalized_candidates.size == 1
      return Result.new(status: :found, path: normalized_candidates.first, match_type: :normalized, candidates: normalized_candidates)
    end

    if normalized_candidates.size > 1
      return Result.new(status: :ambiguous, path: nil, match_type: :ambiguous, candidates: normalized_candidates)
    end

    extension_fallback = resolve_with_extension_fallback(filename)
    return extension_fallback if extension_fallback

    Result.new(status: :missing, path: nil, match_type: :missing, candidates: [])
  end

  private

  def build_index!
    unless @root_path.directory?
      raise ArgumentError, "Media directory not found: #{@root_path}"
    end

    Dir.glob(@root_path.join("*").to_s).each do |path|
      next unless File.file?(path)

      basename = File.basename(path)
      @exact_map[basename] = path
      @casefold_map[basename.downcase] ||= path
      @normalized_map[normalize(basename)] << path
      @normalized_base_map[normalize(File.basename(basename, ".*"))] << path
    end
  end

  def resolve_with_extension_fallback(filename)
    normalized_base = normalize(File.basename(filename, ".*"))
    base_candidates = @normalized_base_map[normalized_base]
    return nil if base_candidates.empty?

    requested_extension = File.extname(filename).delete(".").downcase
    extension_priority = [ requested_extension ] + EXTENSION_EQUIVALENTS.fetch(requested_extension, [])

    preferred_candidates = base_candidates.select do |path|
      extension_priority.include?(File.extname(path).delete(".").downcase)
    end

    return nil if preferred_candidates.empty?
    if preferred_candidates.size == 1
      return Result.new(
        status: :found,
        path: preferred_candidates.first,
        match_type: :extension_fallback,
        candidates: preferred_candidates
      )
    end

    ranked = preferred_candidates.group_by { |path| extension_priority.index(File.extname(path).delete(".").downcase) || Float::INFINITY }
    best_rank = ranked.keys.min
    best_candidates = ranked.fetch(best_rank)
    if best_candidates.size == 1
      return Result.new(
        status: :found,
        path: best_candidates.first,
        match_type: :extension_fallback,
        candidates: best_candidates
      )
    end

    Result.new(status: :ambiguous, path: nil, match_type: :ambiguous_extension, candidates: best_candidates)
  end

  def normalize(name)
    name
      .unicode_normalize(:nfd)
      .gsub(/\p{Mn}/, "")
      .downcase
      .gsub(/[[:space:]]+/, " ")
      .strip
  end
end
