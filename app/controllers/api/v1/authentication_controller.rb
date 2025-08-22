# frozen_string_literal: true

module Api
  module V1
    class AuthenticationController < Api::BaseController
      skip_before_action :authenticate_request

      def create
        result = AuthenticationService.register(**registration_params)
        render_result(result, :created, :unprocessable_content)
      end

      def login
        result = AuthenticationService.authenticate(**login_params)
        render_result(result, :ok, :unauthorized)
      end

      private

      def registration_params
        params.require(:user).permit(:email, :initial_balance).to_h.symbolize_keys
      end

      def login_params
        params.require(:user).permit(:email).to_h.symbolize_keys
      end
    end
  end
end
