module CsvHelpers
  TRANSACTION_HEADERS = %w[
    insider_name relationship security_designation issuer_name ticker
    transaction_id transaction_date filing_date ownership_type
    nature_of_transaction number_of_securities unit_price balance
  ].freeze

  ISSUER_HEADERS = %w[ticker name sector home_page].freeze

  def transaction_csv_content(rows)
    lines = rows.map { |r| r.join(",") }
    ([TRANSACTION_HEADERS.join(",")] + lines).join("\n") + "\n"
  end

  def issuer_csv_content(rows)
    lines = rows.map { |r| r.join(",") }
    ([ISSUER_HEADERS.join(",")] + lines).join("\n") + "\n"
  end

  # Yields a Tempfile path — use in service specs
  def csv_with(content)
    Tempfile.open(["test_import", ".csv"]) do |f|
      f.write(content)
      f.flush
      yield f.path
    end
  end

  # Returns a Rack::Test::UploadedFile — use in request specs
  def csv_upload(content, filename: "test.csv")
    Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: filename)
  end
end

RSpec.configure do |config|
  config.include CsvHelpers
end
