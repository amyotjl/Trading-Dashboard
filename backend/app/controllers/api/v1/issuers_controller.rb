module Api
  module V1
    class IssuersController < ApplicationController
      PER_PAGE_DEFAULT = 25
      PER_PAGE_MAX     = 100

      def show
        issuer = Issuer.find_by!(ticker: params[:ticker])
        issuer = enrich_if_needed(issuer)
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

      def trade_events
        txns = Transaction
          .for_ticker(params[:ticker])
          .where.not(number_of_securities: nil)
          .where.not(number_of_securities: 0)
          .select(:transaction_date, :number_of_securities)

        grouped = txns.group_by { |t| t.transaction_date.to_s }
        result = grouped.flat_map do |date, group|
          events = []
          events << { date: date, type: "buy" }  if group.any? { |t| t.number_of_securities > 0 }
          events << { date: date, type: "sell" } if group.any? { |t| t.number_of_securities < 0 }
          events
        end.sort_by { |e| e[:date] }

        render json: result
      end

      def ohlcv
        data = IssuerEnrichmentService.fetch_ohlcv(params[:ticker])
        if data
          render json: data
        else
          render json: { error: "OHLCV data not available" }, status: :not_found
        end
      end

      private

      def enrich_if_needed(issuer)
        return issuer unless issuer.ticker.present?
        return issuer if issuer.sector.present? && issuer.home_page.present? && issuer.description.present?

        IssuerEnrichmentService.new(issuer).call
      end

      def serialize_issuer(i)
        {
          id:          i.id,
          ticker:      i.ticker,
          name:        i.name,
          sector:      i.sector,
          home_page:   i.home_page,
          description: i.description
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
