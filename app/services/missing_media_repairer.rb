require "digest"
require "stringio"

class MissingMediaRepairer
  IMAGE_EXTENSIONS = %w[jpg jpeg png webp gif bmp tif tiff].freeze

  Result = Struct.new(
    :processed,
    :repaired,
    :already_attached,
    :unresolved,
    :ambiguous,
    :errors,
    keyword_init: true
  )

  def initialize(media_root:, scope: QuestionMediaLink.where(status: :missing), dry_run: true, limit: nil)
    @media_root = Pathname(media_root)
    @scope = scope
    @dry_run = dry_run
    @limit = limit
    @resolver = MediaFileResolver.new(@media_root)
  end

  def call
    result = Result.new(
      processed: 0,
      repaired: 0,
      already_attached: 0,
      unresolved: 0,
      ambiguous: 0,
      errors: 0
    )

    relation = @scope.includes(:media_asset).order(:id)
    relation = relation.limit(@limit) if @limit.present? && @limit.to_i > 0

    relation.find_each do |link|
      result.processed += 1
      resolution = @resolver.resolve(link.source_filename)

      if resolution.status == :missing
        result.unresolved += 1
        next
      end

      if resolution.status == :ambiguous
        result.ambiguous += 1
        next
      end

      begin
        if link.media_asset&.original_file&.attached?
          result.already_attached += 1
          next if @dry_run

          link.update!(status: :attached)
          next
        end

        result.repaired += 1
        next if @dry_run

        repair_link!(link, resolution.path)
      rescue StandardError
        result.errors += 1
      end
    end

    result
  end

  private

  def repair_link!(link, resolved_path)
    media_asset = link.media_asset || build_media_asset_for_link(link)
    attach_media_file!(media_asset, resolved_path, link.source_filename)
    media_asset.processing_status = :attached
    media_asset.save!

    link.update!(
      media_asset: media_asset,
      status: :attached
    )
  end

  def build_media_asset_for_link(link)
    MediaAsset.new(
      source_filename: link.source_filename,
      kind: MediaAsset.kinds.fetch(infer_media_kind(link.source_filename).to_s),
      normalized_filename: normalize_filename(link.source_filename)
    )
  end

  def attach_media_file!(media_asset, file_path, referenced_filename)
    filename = File.basename(file_path)
    content_type = Marcel::MimeType.for(Pathname(file_path), name: filename)
    checksum = Digest::SHA256.file(file_path).hexdigest

    media_asset.original_file.attach(
      io: StringIO.new(File.binread(file_path)),
      filename: filename,
      content_type: content_type
    )

    stat = File.stat(file_path)
    metadata = media_asset.metadata.presence || {}
    media_asset.byte_size = stat.size
    media_asset.content_type = content_type
    media_asset.checksum_sha256 = checksum
    media_asset.metadata = metadata.merge(
      "resolved_filename" => filename,
      "referenced_filename" => referenced_filename
    )
  end

  def infer_media_kind(filename)
    extension = File.extname(filename).delete(".").downcase
    IMAGE_EXTENSIONS.include?(extension) ? :image : :video
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
end
