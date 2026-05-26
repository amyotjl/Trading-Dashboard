require "csv"

class IssuerImportService
  Result = Struct.new(:updated, :created, :errors, keyword_init: true)

  def initialize(file_path_or_io)
    @source = file_path_or_io
  end

  def call
    updated = 0
    created = 0
    errors  = []
    row_num = 1

    Rails.logger.info "[Import:Issuers] Starting import from #{@source}"

    CSV.foreach(@source, headers: true) do |row|
      row_num += 1
      ticker    = row["ticker"].to_s.strip.presence
      name      = row["name"].to_s.strip
      sector    = row["sector"].to_s.strip.presence
      home_page = row["home_page"].to_s.strip.presence

      issuer = ticker ? Issuer.find_by(ticker: ticker) : Issuer.find_by(name: name, ticker: nil)

      if issuer
        issuer.update!(
          name:      name.presence || issuer.name,
          sector:    sector    || issuer.sector,
          home_page: home_page || issuer.home_page
        )
        updated += 1
        Rails.logger.debug "[Import:Issuers] Row #{row_num}: updated ticker=#{ticker || name}"
      else
        Issuer.create!(name: name, ticker: ticker, sector: sector, home_page: home_page)
        created += 1
        Rails.logger.debug "[Import:Issuers] Row #{row_num}: created ticker=#{ticker || name}"
      end
    rescue => e
      errors << { row: row_num, message: e.message }
      Rails.logger.error "[Import:Issuers] Row #{row_num} error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    end

    Rails.logger.info "[Import:Issuers] Done — created: #{created}, updated: #{updated}, errors: #{errors.size}"
    Result.new(updated: updated, created: created, errors: errors)
  end
end
