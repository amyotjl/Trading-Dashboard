module Api
  module V1
    module Imports
      class TransactionsController < ApplicationController
        def create
          unless params[:file].present?
            return render json: { error: "No file provided" }, status: :unprocessable_entity
          end

          file = params[:file]
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
