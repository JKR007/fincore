# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      def balance
        result = current_user.get_balance_info
        render_result(result, :ok, :internal_server_error)
      end

      def update_balance
        result = current_user.process_balance_operation!(balance_params[:operation], balance_params[:amount], description: balance_params[:description])
        render_result(result, :ok, :unprocessable_entity)
      end

      private

      def balance_params
        params.require(:balance).permit(:operation, :amount, :description)
      end
    end
  end
end
