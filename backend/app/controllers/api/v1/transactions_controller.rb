module Api
  module V1
    class TransactionsController < ApplicationController
      PER_PAGE_DEFAULT = 25
      PER_PAGE_MAX     = 100

      def index
        per_page = [[params[:per_page].to_i, 1].max, PER_PAGE_MAX].min
        per_page = PER_PAGE_DEFAULT if per_page.zero?
        page     = [params[:page].to_i, 1].max

        scope = Transaction
          .filtered(filter_params)
          .sorted(params[:sort], params[:direction])
          .includes(:insider, :issuer, :nature_of_transaction, :ownership_type,
                    :security_designation, :relationships)

        total  = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page)

        render json: {
          data: records.map { |t| serialize_transaction(t) },
          meta: { total: total, page: page, per_page: per_page,
                  total_pages: (total.to_f / per_page).ceil }
        }
      end

      private

      def filter_params
        params.permit(:date_from, :date_to, :ticker, :insider_name, :nature_of_transaction_id)
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
          issuer_name:           t.issuer.name,
          ticker:                t.issuer.ticker,
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
