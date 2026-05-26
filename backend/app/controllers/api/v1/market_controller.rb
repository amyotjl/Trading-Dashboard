require "net/http"
require "json"

module Api
  module V1
    class MarketController < ApplicationController
      ENRICHMENT_URL = ENV.fetch("ENRICHMENT_SERVICE_URL", "http://enrichment:8000")
      TIMEOUT = 30

      def indices
        proxy("/market/indices")
      end

      def sectors
        proxy("/market/sectors")
      end

      def movers
        type = %w[gainers losers active].include?(params[:type]) ? params[:type] : "gainers"
        proxy("/market/movers?type=#{type}")
      end

      private

      def proxy(path)
        uri = URI("#{ENRICHMENT_URL}#{path}")
        response = Net::HTTP.start(uri.host, uri.port, read_timeout: TIMEOUT, open_timeout: 10) do |http|
          http.request(Net::HTTP::Get.new(uri))
        end
        if response.is_a?(Net::HTTPSuccess)
          render json: JSON.parse(response.body)
        else
          render json: { error: "Market data unavailable" }, status: :service_unavailable
        end
      rescue => e
        Rails.logger.error "[Market] proxy #{path} failed: #{e.message}"
        render json: { error: "Market data unavailable" }, status: :service_unavailable
      end
    end
  end
end
