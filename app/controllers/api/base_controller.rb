# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    before_action :authenticate_request

    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from StandardError, with: :internal_server_error

    private

    attr_reader :current_user

    def authenticate_request
      header = request.headers["Authorization"]
      token = header.split.last if header&.start_with?("Bearer ")

      return render_unauthorized unless token

      begin
        decoded = JsonWebToken.decode(token)
        @current_user = User.find(decoded[:user_id])
      rescue ActiveRecord::RecordNotFound, JWT::DecodeError
        render_unauthorized
      end
    end

    def render_unauthorized
      render json: { success: false, errors: [ "Unauthorized" ] }, status: :unauthorized
    end

    def not_found(exception)
      render json: { success: false, errors: [ exception.message ] }, status: :not_found
    end

    def unprocessable_entity(exception)
      render json: { success: false, errors: exception.record.errors.full_messages }, status: :unprocessable_entity
    end

    def internal_server_error(_exception)
      render json: { success: false, errors: [ "Internal server error" ] }, status: :internal_server_error
    end

    def render_result(result, success_status, error_status)
      status = result[:success] ? success_status : error_status
      render json: result, status: status
    end
  end
end
