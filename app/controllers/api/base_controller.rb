# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    before_action :authenticate_request

    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_content
    rescue_from StandardError, with: :internal_server_error

    private

    attr_reader :current_user

    def authenticate_request
      header = request.headers["Authorization"]
      token = header.split.last if header

      begin
        decoded = JsonWebToken.decode(token)
        @current_user = User.find(decoded[:user_id])
      rescue ActiveRecord::RecordNotFound, JWT::DecodeError, JsonWebToken::InvalidTokenError, JsonWebToken::ExpiredTokenError, JsonWebToken::MissingTokenError
        render_unauthorized
      end
    end

    def render_unauthorized
      render json: { success: false, errors: [ "Unauthorized" ] }, status: :unauthorized
    end

    def not_found(exception)
      render json: { success: false, errors: [ exception.message ] }, status: :not_found
    end

    def unprocessable_content(exception)
      render json: { success: false, errors: exception.record.errors.full_messages }, status: :unprocessable_content
    end

    def internal_server_error(exception)
      log_error(exception, "Internal server error")
      render json: { success: false, errors: [ "Internal server error" ] }, status: :internal_server_error
    end

    def render_result(result, success_status, error_status)
      status = result[:success] ? success_status : error_status
      render json: result, status: status
    end

    def log_error(error, context)
      Rails.logger.error({ message: "#{context}: #{error.message}", error_class: error.class.name, backtrace: error.backtrace&.first(5)  }.to_json)
    end
  end
end
