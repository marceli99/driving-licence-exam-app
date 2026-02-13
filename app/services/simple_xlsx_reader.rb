require "cgi"
require "open3"

class SimpleXlsxReader
  Row = Struct.new(:number, :cells, keyword_init: true)

  def initialize(path)
    @path = Pathname(path)
  end

  def each_row
    return enum_for(:each_row) unless block_given?

    shared_strings = load_shared_strings
    sheet_xml = read_zip_entry("xl/worksheets/sheet1.xml")

    sheet_xml.scan(/<row r="(\d+)"[^>]*>(.*?)<\/row>/m).each do |number_string, row_xml|
      row_number = number_string.to_i
      cells = {}

      row_xml.scan(/<c r="([A-Z]+)#{row_number}"([^>]*)>(.*?)<\/c>/m).each do |column, attrs, cell_xml|
        value = cell_xml[/<v>(.*?)<\/v>/m, 1]
        next if value.nil?

        parsed =
          if attrs.include?('t="s"')
            shared_strings[value.to_i].to_s
          else
            CGI.unescapeHTML(value.to_s)
          end

        cells[column] = parsed
      end

      yield Row.new(number: row_number, cells: cells)
    end
  end

  private

  def load_shared_strings
    xml = read_zip_entry("xl/sharedStrings.xml")
    xml.scan(/<si>(.*?)<\/si>/m).map do |fragment_array|
      fragment = fragment_array.first
      text = fragment.scan(/<t[^>]*>(.*?)<\/t>/m).map { |cell| cell.first }.join
      CGI.unescapeHTML(text)
    end
  end

  def read_zip_entry(entry)
    stdout, stderr, status = Open3.capture3("unzip", "-p", @path.to_s, entry)
    return stdout if status.success?

    raise "Cannot read #{entry} from #{@path}: #{stderr.presence || 'unknown unzip error'}"
  end
end
