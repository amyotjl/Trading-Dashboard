module Api
  module V1
    class NatureOfTransactionsController < ApplicationController
      def index
        records = NatureOfTransaction.order(:code)
        render json: records.map { |n| { id: n.id, code: n.code, description: n.description } }
      end
    end
  end
end
