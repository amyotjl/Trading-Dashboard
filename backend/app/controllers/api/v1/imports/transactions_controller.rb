module Api
  module V1
    module Imports
      class TransactionsController < ApplicationController
        def create
          unless params[:file].present?
            Rails.logger.warn "[Import:Transactions] Upload rejected — no file in request"
            return render json: { error: "No file provided" }, status: :unprocessable_entity
          end

          file = params[:file]
          Rails.logger.info "[Import:Transactions] Received upload: #{file.original_filename} (#{file.size} bytes)"

          result = TransactionImportService.new(file.path).call

          render json: {
            inserted: result.inserted,
            skipped:  result.skipped,
            errors:   result.errors
          }
        end
      end
    end
  end
end
