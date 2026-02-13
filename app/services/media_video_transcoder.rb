require "open3"
require "tempfile"

class MediaVideoTranscoder
  class TranscodeError < StandardError; end

  def initialize(media_asset, ffmpeg_path: "ffmpeg", ffprobe_path: "ffprobe", force: false)
    @media_asset = media_asset
    @ffmpeg_path = ffmpeg_path
    @ffprobe_path = ffprobe_path
    @force = force
  end

  def call
    validate_media_asset!

    return :skipped if @media_asset.web_file.attached? && !@force

    output_file = Tempfile.new([ output_basename, ".mp4" ])
    output_file.close

    @media_asset.original_file.open(tmpdir: Dir.tmpdir) do |source_file|
      run_ffmpeg!(source_file.path, output_file.path)
    end

    attach_web_variant!(output_file.path)
    :converted
  ensure
    output_file&.close!
  end

  private

  def validate_media_asset!
    raise TranscodeError, "Media asset #{@media_asset.id} is not a video." unless @media_asset.kind_video?
    raise TranscodeError, "Media asset #{@media_asset.id} has no original file attached." unless @media_asset.original_file.attached?
  end

  def run_ffmpeg!(source_path, output_path)
    command = [
      @ffmpeg_path,
      "-y",
      "-i", source_path,
      "-c:v", "libx264",
      "-preset", "veryfast",
      "-crf", "23",
      "-movflags", "+faststart",
      "-c:a", "aac",
      "-b:a", "128k",
      output_path
    ]

    _stdout, stderr, status = Open3.capture3(*command)
    return if status.success?

    raise TranscodeError, "ffmpeg failed for MediaAsset ##{@media_asset.id}: #{stderr.to_s.lines.last(5).join.strip}"
  end

  def attach_web_variant!(output_path)
    output_filename = "#{output_basename}.mp4"
    output_size = File.size(output_path)
    checksum = Digest::SHA256.file(output_path).hexdigest
    duration_ms, width, height = probe_video_details(output_path)

    File.open(output_path, "rb") do |io|
      @media_asset.web_file.attach(
        io: io,
        filename: output_filename,
        content_type: "video/mp4"
      )
    end

    metadata = @media_asset.metadata.dup
    metadata["web_variant"] = {
      "filename" => output_filename,
      "checksum_sha256" => checksum,
      "byte_size" => output_size
    }

    @media_asset.update!(
      processing_status: :attached,
      duration_ms: duration_ms || @media_asset.duration_ms,
      width: width || @media_asset.width,
      height: height || @media_asset.height,
      metadata: metadata
    )
  end

  def probe_video_details(path)
    command = [
      @ffprobe_path,
      "-v", "error",
      "-select_streams", "v:0",
      "-show_entries", "stream=width,height:format=duration",
      "-of", "default=noprint_wrappers=1:nokey=1",
      path
    ]

    output, _stderr, status = Open3.capture3(*command)
    return [ nil, nil, nil ] unless status.success?

    values = output.lines.map(&:strip).reject(&:empty?)
    width = integer_or_nil(values[0])
    height = integer_or_nil(values[1])
    duration_ms = float_to_ms(values[2])
    [ duration_ms, width, height ]
  end

  def output_basename
    File.basename(@media_asset.source_filename.to_s, ".*").presence || "video-#{@media_asset.id}"
  end

  def integer_or_nil(value)
    return nil if value.blank?
    Integer(value, exception: false)
  end

  def float_to_ms(value)
    return nil if value.blank?
    number = Float(value, exception: false)
    return nil if number.nil?

    (number * 1000).round
  end
end
