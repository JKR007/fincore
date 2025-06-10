# frozen_string_literal: true

module Api
  module V1
    class TransfersController < BaseController
      def create
        result = TransferService.transfer_by_email(from_user: current_user, to_email: transfer_params[:to_email], amount: transfer_params[:amount], description: transfer_params[:description])
        render_result(result, :created, :unprocessable_entity)
      end

      private

      def transfer_params
        params.require(:transfer).permit(:to_email, :amount, :description)
      end
    end
  end
end
