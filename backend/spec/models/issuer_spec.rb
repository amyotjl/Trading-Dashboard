require "rails_helper"

RSpec.describe Issuer, type: :model do
  it { is_expected.to have_many(:transactions) }
  it { is_expected.to validate_presence_of(:name) }

  describe "ticker uniqueness" do
    it "allows multiple issuers with nil ticker" do
      create(:issuer, ticker: nil)
      other = build(:issuer, ticker: nil)
      expect(other).to be_valid
    end

    it "rejects duplicate non-nil tickers" do
      create(:issuer, ticker: "CNQ")
      dup = build(:issuer, ticker: "CNQ")
      expect(dup).not_to be_valid
    end
  end
end
