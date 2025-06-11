# frozen_string_literal: true

module Api
  module V1
    class TransfersController < BaseController
      def create
        result = TransferService.transfer_by_email(from_user: current_user, **transfer_params)
        render_result(result, :created, :unprocessable_entity)
      end

      private

      def transfer_params
        permitted = params.require(:transfer).permit(:to_email, :amount, :description)
        { to_email: permitted[:to_email], amount: permitted[:amount], description: permitted[:description] }
      end
    end
  end
end
