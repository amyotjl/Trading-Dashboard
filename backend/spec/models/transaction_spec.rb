require "rails_helper"

RSpec.describe Transaction, type: :model do
  it { is_expected.to belong_to(:insider) }
  it { is_expected.to belong_to(:issuer) }
  it { is_expected.to belong_to(:security_designation) }
  it { is_expected.to belong_to(:ownership_type) }
  it { is_expected.to belong_to(:nature_of_transaction) }
  it { is_expected.to have_many(:transaction_relationships) }
  it { is_expected.to have_many(:relationships).through(:transaction_relationships) }

  it { is_expected.to validate_presence_of(:sedi_transaction_id) }
  it { is_expected.to validate_presence_of(:transaction_date) }
  it { is_expected.to validate_presence_of(:filing_date) }

  describe "uniqueness" do
    let!(:existing) { create(:transaction) }

    it "rejects a duplicate (same sedi_id + date + security + ownership)" do
      dup = build(:transaction,
        sedi_transaction_id:  existing.sedi_transaction_id,
        transaction_date:     existing.transaction_date,
        security_designation: existing.security_designation,
        ownership_type:       existing.ownership_type
      )
      expect(dup).not_to be_valid
    end

    it "allows same sedi_id on a different date" do
      other = build(:transaction,
        sedi_transaction_id:  existing.sedi_transaction_id,
        transaction_date:     existing.transaction_date + 1
      )
      expect(other).to be_valid
    end
  end

  describe ".filtered" do
    let!(:t1) { create(:transaction, transaction_date: "2025-01-10") }
    let!(:t2) { create(:transaction, transaction_date: "2025-03-01") }

    it "filters by date_from" do
      result = Transaction.filtered(date_from: "2025-02-01")
      expect(result).to include(t2)
      expect(result).not_to include(t1)
    end

    it "filters by date_to" do
      result = Transaction.filtered(date_to: "2025-01-31")
      expect(result).to include(t1)
      expect(result).not_to include(t2)
    end
  end
end
