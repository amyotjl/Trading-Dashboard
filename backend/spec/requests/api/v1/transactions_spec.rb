require "rails_helper"

RSpec.describe "GET /api/v1/transactions", type: :request do
  let!(:t1) { create(:transaction, transaction_date: "2025-01-10", filing_date: "2025-01-15") }
  let!(:t2) { create(:transaction, transaction_date: "2025-03-01", filing_date: "2025-03-05") }

  it "returns paginated transactions" do
    get "/api/v1/transactions"
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["data"]).to be_an(Array)
    expect(json["meta"]["total"]).to eq(2)
  end

  it "filters by date_from" do
    get "/api/v1/transactions", params: { date_from: "2025-02-01" }
    json = JSON.parse(response.body)
    expect(json["data"].size).to eq(1)
    expect(json["data"].first["transaction_date"]).to eq("2025-03-01")
  end

  it "filters by date_to" do
    get "/api/v1/transactions", params: { date_to: "2025-01-31" }
    json = JSON.parse(response.body)
    expect(json["data"].size).to eq(1)
    expect(json["data"].first["transaction_date"]).to eq("2025-01-10")
  end

  it "respects per_page" do
    get "/api/v1/transactions", params: { per_page: 1, page: 1 }
    json = JSON.parse(response.body)
    expect(json["data"].size).to eq(1)
    expect(json["meta"]["total"]).to eq(2)
  end
end
