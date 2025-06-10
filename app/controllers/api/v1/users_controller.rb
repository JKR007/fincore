# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      def balance
        result = BalanceOperationService.get_balance(user: current_user)
        render_result(result, :ok, :internal_server_error)
      end

      def update_balance
        result = BalanceOperationService.process_balance_operation(user: current_user, operation: balance_params[:operation], amount: balance_params[:amount], description: balance_params[:description])
        render_result(result, :ok, :unprocessable_entity)
      end

      private

      def balance_params
        params.require(:balance).permit(:operation, :amount, :description)
      end
    end
  end
end
