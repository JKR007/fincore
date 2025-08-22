# frozen_string_literal: true

module Api
  module V1
    class TransfersController < Api::BaseController
      def create
        result = TransferService.transfer_by_email(from_user: current_user, **transfer_params)
        render_result(result, :created, :unprocessable_content)
      end

      private

      def permitted_params
        params.require(:transfer).permit(:to_email, :amount, :description).to_h.symbolize_keys
      end

      def transfer_params
        { to_email: permitted_params[:to_email], amount: permitted_params[:amount], description: permitted_params[:description] }
      end
    end
  end
end
