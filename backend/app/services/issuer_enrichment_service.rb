require "net/http"
require "json"

class IssuerEnrichmentService
  ENRICHMENT_URL = ENV.fetch("ENRICHMENT_SERVICE_URL", "http://enrichment:8000")
  TIMEOUT_SECONDS = 10

  def initialize(issuer)
    @issuer = issuer
  end

  def call
    return @issuer if @issuer.ticker.blank?

    data = fetch(URI.encode_www_form_component(@issuer.ticker))
    return @issuer unless data

    updates = {}
    updates[:sector]      = data["sector"]      if data["sector"].present?      && @issuer.sector.blank?
    updates[:home_page]   = data["home_page"]   if data["home_page"].present?   && @issuer.home_page.blank?
    updates[:description] = data["description"] if data["description"].present? && @issuer.description.blank?
    updates[:name]        = data["name"]         if data["name"].present?        && @issuer.name == @issuer.ticker

    if updates.any?
      @issuer.update!(updates)
      Rails.logger.info "[Enrich] #{@issuer.ticker}: updated #{updates.keys.join(', ')}"
    else
      Rails.logger.debug "[Enrich] #{@issuer.ticker}: nothing new to update"
    end

    @issuer
  rescue => e
    Rails.logger.error "[Enrich] #{@issuer.ticker} failed: #{e.message}"
    @issuer
  end

  def self.fetch_ohlcv(ticker, period: "2y")
    encoded = URI.encode_www_form_component(ticker)
    uri = URI("#{ENRICHMENT_URL}/ohlcv/#{encoded}?period=#{period}")
    response = Net::HTTP.start(uri.host, uri.port, read_timeout: 30, open_timeout: 10) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    return nil unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "[OHLCV] #{ticker} failed: #{e.message}"
    nil
  end

  private

  def fetch(encoded_ticker)
    uri = URI("#{ENRICHMENT_URL}/enrich/#{encoded_ticker}")
    req = Net::HTTP::Get.new(uri)
    response = Net::HTTP.start(uri.host, uri.port, read_timeout: TIMEOUT_SECONDS, open_timeout: TIMEOUT_SECONDS) do |http|
      http.request(req)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn "[Enrich] #{@issuer.ticker}: enrichment service returned #{response.code}"
      return nil
    end

    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "[Enrich] HTTP request failed for #{@issuer.ticker}: #{e.message}"
    nil
  end
end
