require "rails_helper"

RSpec.describe "Issuers API", type: :request do
  let!(:issuer) { create(:issuer, ticker: "CNQ", name: "Canadian Natural Resources", sector: "Energy") }

  describe "GET /api/v1/issuers/:ticker" do
    it "returns issuer metadata" do
      get "/api/v1/issuers/CNQ"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["ticker"]).to eq("CNQ")
      expect(json["sector"]).to eq("Energy")
    end

    it "returns 404 for unknown ticker" do
      get "/api/v1/issuers/UNKNOWN"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/issuers/:ticker/transactions" do
    let!(:t1) { create(:transaction, issuer: issuer) }
    let!(:t2) { create(:transaction) }

    it "returns only transactions for that ticker" do
      get "/api/v1/issuers/CNQ/transactions"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(1)
      expect(json["data"].first["id"]).to eq(t1.id)
    end
  end
end
