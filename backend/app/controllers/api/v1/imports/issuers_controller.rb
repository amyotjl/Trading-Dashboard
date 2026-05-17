module Api
  module V1
    module Imports
      class IssuersController < ApplicationController
        def create
          unless params[:file].present?
            return render json: { error: "No file provided" }, status: :unprocessable_entity
          end

          file = params[:file]
          result = IssuerImportService.new(file.path).call

          render json: {
            created: result.created,
            updated: result.updated,
            errors:  result.errors
          }
        end
      end
    end
  end
end
