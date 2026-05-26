module Api
  module V1
    class TransactionsController < ApplicationController
      PER_PAGE_DEFAULT = 25
      PER_PAGE_MAX     = 100

      def insider_sentiment
        scope = Transaction.where.not(number_of_securities: nil)
        scope = scope.where("transaction_date >= ?", params[:date_from]) if params[:date_from].present?
        scope = scope.where("transaction_date <= ?", params[:date_to])   if params[:date_to].present?

        results = scope.group(:transaction_date).order(:transaction_date).select(
          "transaction_date AS date",
          "COUNT(*) FILTER (WHERE number_of_securities > 0) AS buys",
          "COUNT(*) FILTER (WHERE number_of_securities < 0) AS sells",
          "COALESCE(SUM(number_of_securities::numeric * unit_price) FILTER (WHERE number_of_securities > 0), 0)::float AS buy_value",
          "COALESCE(ABS(SUM(number_of_securities::numeric * unit_price)) FILTER (WHERE number_of_securities < 0), 0)::float AS sell_value"
        )

        render json: results.map { |r|
          {
            date:       r["date"].to_s,
            buys:       r["buys"].to_i,
            sells:      r["sells"].to_i,
            buy_value:  r["buy_value"].to_f,
            sell_value: r["sell_value"].to_f
          }
        }
      end

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
        params.permit(:date_from, :date_to, :ticker, :insider_name, :nature_of_transaction_id,
                      :min_insiders, :insider_date_from, :insider_date_to)
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
