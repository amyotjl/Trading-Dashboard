module Api
  module V1
    class InsidersController < ApplicationController
      def index
        query   = params[:q].to_s.strip
        records = query.present? ? Insider.where("name ILIKE ?", "%#{query}%") : Insider.all
        records = records.order(:name).limit(20)
        render json: records.map { |i| { id: i.id, name: i.name } }
      end
    end
  end
end
