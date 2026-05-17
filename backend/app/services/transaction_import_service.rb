require "csv"

class TransactionImportService
  Result = Struct.new(:inserted, :skipped, :errors, keyword_init: true)

  NO_SYMBOL = "No Symbol Found"

  def initialize(file_path_or_io)
    @source = file_path_or_io
  end

  def call
    inserted = 0
    skipped  = 0
    errors   = []
    row_num  = 1

    ActiveRecord::Base.transaction do
      CSV.foreach(@source, headers: true) do |row|
        row_num += 1
        result = import_row(row)
        case result
        when :inserted then inserted += 1
        when :skipped  then skipped  += 1
        end
      rescue => e
        errors << { row: row_num, message: e.message }
      end
    end

    Result.new(inserted: inserted, skipped: skipped, errors: errors)
  end

  private

  def import_row(row)
    insider              = find_or_create_insider(row["insider_name"].to_s.strip)
    issuer               = find_or_create_issuer(row["issuer_name"].to_s.strip, row["ticker"].to_s.strip)
    security_designation = find_or_create_security_designation(row["security_designation"].to_s.strip)
    ownership_type       = find_or_create_ownership_type(row["ownership_type"].to_s.strip)
    nature_of_transaction = find_or_create_nature_of_transaction(row["nature_of_transaction"].to_s.strip)
    relationship_records = parse_relationships(row["relationship"].to_s.strip)

    attrs = {
      sedi_transaction_id:      Integer(row["transaction_id"]),
      transaction_date:         Date.parse(row["transaction_date"]),
      filing_date:              Date.parse(row["filing_date"]),
      number_of_securities:     row["number_of_securities"].present? ? Integer(row["number_of_securities"]) : nil,
      unit_price:               row["unit_price"].present? ? BigDecimal(row["unit_price"]) : nil,
      balance:                  row["balance"].present? ? Integer(row["balance"]) : nil,
      insider:                  insider,
      security_designation:     security_designation,
      issuer:                   issuer,
      ownership_type:           ownership_type,
      nature_of_transaction:    nature_of_transaction
    }

    txn = Transaction.find_by(
      sedi_transaction_id:     attrs[:sedi_transaction_id],
      transaction_date:        attrs[:transaction_date],
      security_designation_id: security_designation.id,
      ownership_type_id:       ownership_type.id
    )

    if txn
      :skipped
    else
      txn = Transaction.create!(attrs)
      relationship_records.each do |rel|
        TransactionRelationship.find_or_create_by!(transaction: txn, relationship: rel)
      end
      :inserted
    end
  end

  def find_or_create_insider(name)
    Insider.find_or_create_by!(name: name)
  end

  def find_or_create_issuer(name, ticker_raw)
    ticker = ticker_raw.blank? || ticker_raw == NO_SYMBOL ? nil : ticker_raw

    if ticker
      Issuer.find_or_create_by!(ticker: ticker) do |i|
        i.name = name
      end
    else
      Issuer.find_or_create_by!(name: name, ticker: nil)
    end
  end

  def find_or_create_security_designation(name)
    SecurityDesignation.find_or_create_by!(name: name)
  end

  def find_or_create_ownership_type(raw)
    if raw.start_with?("Indirect Ownership")
      entity = raw.sub("Indirect Ownership", "").strip
      entity = nil if entity.blank?
      OwnershipType.find_or_create_by!(category: "Indirect", entity_name: entity)
    else
      OwnershipType.find_or_create_by!(category: "Direct", entity_name: nil)
    end
  end

  def find_or_create_nature_of_transaction(raw)
    # Format: "56 - Grant of rights" or "38 - Redemption, retraction, ..."
    match = raw.match(/\A(\d+)\s*-\s*(.+)\z/)
    if match
      NatureOfTransaction.find_or_create_by!(code: match[1], description: match[2].strip)
    else
      NatureOfTransaction.find_or_create_by!(code: "00", description: raw.presence || "Unknown")
    end
  end

  def parse_relationships(raw)
    # Each part looks like "4 - Director of Issuer"
    # Multiple values are comma-separated between the code and description groups
    # e.g. "4 - Director of Issuer, 5 - Senior Officer of Issuer"
    # Split on ", N - " pattern to handle descriptions that contain commas
    parts = raw.split(/,\s*(?=\d+\s*-)/)
    parts.map do |part|
      match = part.strip.match(/\A(\d+)\s*-\s*(.+)\z/)
      if match
        Relationship.find_or_create_by!(code: match[1], description: match[2].strip)
      else
        Relationship.find_or_create_by!(code: "0", description: part.strip.presence || "Unknown")
      end
    end
  end
end
