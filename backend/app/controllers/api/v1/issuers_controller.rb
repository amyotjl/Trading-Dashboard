module Api
  module V1
    class IssuersController < ApplicationController
      PER_PAGE_DEFAULT = 25
      PER_PAGE_MAX     = 100

      def show
        issuer = Issuer.find_by!(ticker: params[:ticker])
        render json: serialize_issuer(issuer)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Issuer not found" }, status: :not_found
      end

      def transactions
        issuer = Issuer.find_by!(ticker: params[:ticker])

        per_page = [[params[:per_page].to_i, 1].max, PER_PAGE_MAX].min
        per_page = PER_PAGE_DEFAULT if per_page.zero?
        page     = [params[:page].to_i, 1].max

        scope = Transaction
          .for_ticker(params[:ticker])
          .sorted(params[:sort], params[:direction])
          .includes(:insider, :nature_of_transaction, :ownership_type,
                    :security_designation, :relationships)

        total   = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page)

        render json: {
          issuer: serialize_issuer(issuer),
          data:   records.map { |t| serialize_transaction(t) },
          meta:   { total: total, page: page, per_page: per_page,
                    total_pages: (total.to_f / per_page).ceil }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Issuer not found" }, status: :not_found
      end

      private

      def serialize_issuer(i)
        {
          id:        i.id,
          ticker:    i.ticker,
          name:      i.name,
          sector:    i.sector,
          home_page: i.home_page
        }
      end

      def serialize_transaction(t)
        {
          id:                    t.id,
          sedi_transaction_id:   t.sedi_transaction_id,
          transaction_date:      t.transaction_date,
          filing_date:           t.filing_date,
          number_of_securities:  t.number_of_securities,
          unit_price:            t.unit_price,
          balance:               t.balance,
          insider_name:          t.insider.name,
          security_designation:  t.security_designation.name,
          ownership_type:        t.ownership_type.category,
          ownership_entity:      t.ownership_type.entity_name,
          nature_of_transaction: "#{t.nature_of_transaction.code} - #{t.nature_of_transaction.description}",
          relationships:         t.relationships.map { |r| "#{r.code} - #{r.description}" }
        }
      end
    end
  end
end
