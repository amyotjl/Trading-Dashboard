require "rails_helper"

RSpec.describe "Imports API", type: :request do
  let(:valid_row) do
    ['"Doe, Jane"', "4 - Director of Issuer", "Common Shares",
     "Acme Corp.", "ACM", "9000099", "2025-02-01", "2025-02-05",
     "Direct Ownership :", "10 - Acquisition or disposition in the public market",
     "500", "12.00", "5000"]
  end

  describe "POST /api/v1/imports" do
    it "imports transactions from a valid CSV and returns inserted/skipped counts" do
      file = csv_upload(transaction_csv_content([valid_row]))
      post "/api/v1/imports", params: { file: file }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["inserted"]).to eq(1)
      expect(json["skipped"]).to eq(0)
      expect(json["errors"]).to be_empty
    end

    it "reports skipped count when the same CSV is imported twice" do
      file1 = csv_upload(transaction_csv_content([valid_row]))
      post "/api/v1/imports", params: { file: file1 }
      expect(response).to have_http_status(:ok)

      file2 = csv_upload(transaction_csv_content([valid_row]))
      post "/api/v1/imports", params: { file: file2 }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["inserted"]).to eq(0)
      expect(json["skipped"]).to eq(1)
    end

    it "returns 422 when no file is provided" do
      post "/api/v1/imports"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to be_present
    end

    it "returns errors array for rows with invalid data and still processes valid rows" do
      bad_row = valid_row.dup
      bad_row[6] = "not-a-date"
      bad_row[5] = "9000100"

      good_row = valid_row.dup
      good_row[5] = "9000101"

      file = csv_upload(transaction_csv_content([bad_row, good_row]))
      post "/api/v1/imports", params: { file: file }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["errors"].size).to eq(1)
      expect(json["errors"].first["row"]).to eq(2)
      expect(json["inserted"]).to eq(1)
    end
  end

  describe "POST /api/v1/imports/issuers" do
    it "creates new issuers from a valid CSV" do
      content = issuer_csv_content([["TST", "Test Corp.", "Technology", "https://test.com"]])
      file = csv_upload(content, filename: "issuers.csv")
      post "/api/v1/imports/issuers", params: { file: file }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["created"]).to eq(1)
      expect(json["updated"]).to eq(0)
      expect(json["errors"]).to be_empty
    end

    it "updates existing issuers" do
      Issuer.create!(name: "Test Corp.", ticker: "TST")
      content = issuer_csv_content([["TST", "Test Corp.", "Finance", "https://test.com"]])
      file = csv_upload(content, filename: "issuers.csv")
      post "/api/v1/imports/issuers", params: { file: file }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["updated"]).to eq(1)
      expect(json["created"]).to eq(0)
      expect(Issuer.find_by(ticker: "TST").sector).to eq("Finance")
    end

    it "returns 422 when no file is provided" do
      post "/api/v1/imports/issuers"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
