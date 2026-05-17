require "rails_helper"

RSpec.describe "POST /api/v1/imports", type: :request do
  let(:csv_content) do
    <<~CSV
      insider_name,relationship,security_designation,issuer_name,ticker,transaction_id,transaction_date,filing_date,ownership_type,nature_of_transaction,number_of_securities,unit_price,balance
      "Doe, Jane",4 - Director of Issuer,Common Shares,Acme Corp.,ACM,9000099,2025-02-01,2025-02-05,Direct Ownership :,10 - Acquisition or disposition in the public market,500,12.00,5000
    CSV
  end

  it "imports transactions and returns a summary" do
    file = Rack::Test::UploadedFile.new(
      StringIO.new(csv_content),
      "text/csv",
      original_filename: "test.csv"
    )
    post "/api/v1/imports", params: { file: file }
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["inserted"]).to eq(1)
    expect(json["skipped"]).to eq(0)
  end

  it "returns 422 when no file is provided" do
    post "/api/v1/imports"
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
