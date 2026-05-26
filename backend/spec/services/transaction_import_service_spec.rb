require "rails_helper"

RSpec.describe TransactionImportService do
  let(:valid_row) do
    ['"Smith, John"', "4 - Director of Issuer", "Common Shares",
     "Acme Corp.", "ACM", "9000001", "2025-01-05", "2025-01-10",
     "Direct Ownership :", "10 - Acquisition or disposition in the public market",
     "1000", "15.00", "50000"]
  end

  describe "#call" do
    it "inserts a new transaction" do
      csv_with(transaction_csv_content([valid_row])) do |path|
        result = described_class.new(path).call
        expect(result.inserted).to eq(1)
        expect(result.skipped).to eq(0)
        expect(result.errors).to be_empty
      end
    end

    it "skips duplicate rows" do
      csv_with(transaction_csv_content([valid_row, valid_row])) do |path|
        result = described_class.new(path).call
        expect(result.inserted).to eq(1)
        expect(result.skipped).to eq(1)
      end
    end

    it "creates normalized lookup records" do
      csv_with(transaction_csv_content([valid_row])) do |path|
        described_class.new(path).call
        expect(Insider.find_by(name: "Smith, John")).to be_present
        expect(Issuer.find_by(ticker: "ACM")).to be_present
        expect(NatureOfTransaction.find_by(code: "10")).to be_present
        expect(OwnershipType.find_by(category: "Direct")).to be_present
      end
    end

    it "handles multi-value relationships" do
      row = valid_row.dup
      row[1] = '"4 - Director of Issuer, 5 - Senior Officer of Issuer"'
      csv_with(transaction_csv_content([row])) do |path|
        described_class.new(path).call
        expect(Transaction.last.relationships.map(&:code)).to match_array(%w[4 5])
      end
    end

    it "parses indirect ownership correctly" do
      row = valid_row.dup
      row[8] = "Indirect OwnershipBeedie Investments Ltd."
      csv_with(transaction_csv_content([row])) do |path|
        described_class.new(path).call
        ot = OwnershipType.find_by(category: "Indirect")
        expect(ot).to be_present
        expect(ot.entity_name).to eq("Beedie Investments Ltd.")
      end
    end

    it "stores nil ticker when SEDI reports No Symbol Found" do
      row = valid_row.dup
      row[4] = "No Symbol Found"
      csv_with(transaction_csv_content([row])) do |path|
        described_class.new(path).call
        expect(Issuer.last.ticker).to be_nil
      end
    end

    it "returns inserted=0, skipped=0, errors=[] for an empty CSV" do
      csv_with(transaction_csv_content([])) do |path|
        result = described_class.new(path).call
        expect(result.inserted).to eq(0)
        expect(result.skipped).to eq(0)
        expect(result.errors).to be_empty
      end
    end

    it "records an error for a row with a malformed date, still processes other rows" do
      bad_row = valid_row.dup
      bad_row[6] = "not-a-date"
      bad_row[5] = "9000002"

      good_row = valid_row.dup
      good_row[5] = "9000003"

      csv_with(transaction_csv_content([bad_row, good_row])) do |path|
        result = described_class.new(path).call
        expect(result.errors.size).to eq(1)
        expect(result.errors.first[:row]).to eq(2)
        expect(result.inserted).to eq(1)
      end
    end

    it "records an error for a row with a blank transaction_id" do
      bad_row = valid_row.dup
      bad_row[5] = ""
      csv_with(transaction_csv_content([bad_row])) do |path|
        result = described_class.new(path).call
        expect(result.errors.size).to eq(1)
        expect(result.inserted).to eq(0)
      end
    end
  end
end
