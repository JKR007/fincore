# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :controller do
  let(:user) { create(:user, balance: 500.0) }

  describe 'GET #balance' do
    context 'with authenticated user' do
      let(:service_response) do
        {
          success: true,
          balance: 500.0,
          user: { email: user.email, balance: 500.0 }
        }
      end

      before do
        authenticate_as(user)
        allow(user).to receive(:get_balance_info).and_return(service_response)
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'calls current_user.get_balance_info' do
        get :balance

        expect(user).to have_received(:get_balance_info)
      end

      it 'returns 200 status' do
        get :balance
        expect(response).to have_http_status(:ok)
      end

      it 'returns balance information' do
        get :balance
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be true
        expect(json_response['balance']).to eq(500.0)
        expect(json_response['user']['email']).to eq(user.email)
      end

      it 'uses current_user context' do
        get :balance
        expect(controller.instance_variable_get(:@current_user)).to eq(user)
      end
    end

    context 'without authentication' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        allow(controller).to receive(:authenticate_request).and_call_original
      end

      it 'returns 401 unauthorized' do
        get :balance
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized error message' do
        get :balance
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['errors']).to include('Unauthorized')
      end
    end

    context 'with service integration' do
      before { authenticate_as(user) }

      it 'delegates to user service method' do
        allow(user).to receive(:get_balance_info).and_return(success: true, balance: 500.0)
        allow(controller).to receive(:current_user).and_return(user)

        get :balance

        expect(user).to have_received(:get_balance_info)
      end

      it 'handles service success response' do
        service_response = { success: true, balance: 750.0, user: { email: user.email, balance: 750.0 } }
        allow(user).to receive(:get_balance_info).and_return(service_response)
        allow(controller).to receive(:current_user).and_return(user)

        get :balance
        json_response = JSON.parse(response.body)

        expect(json_response['balance']).to eq(750.0)
      end

      it 'handles service error response' do
        service_response = { success: false, errors: [ 'Database error' ] }
        allow(user).to receive(:get_balance_info).and_return(service_response)
        allow(controller).to receive(:current_user).and_return(user)

        get :balance

        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'with edge cases' do
      before { authenticate_as(user) }

      it 'handles zero balance user' do
        zero_balance_user = create(:user, balance: 0.0)
        service_response = { success: true, balance: 0.0, user: { email: zero_balance_user.email, balance: 0.0 } }
        allow(zero_balance_user).to receive(:get_balance_info).and_return(service_response)
        allow(controller).to receive(:current_user).and_return(zero_balance_user)

        get :balance
        json_response = JSON.parse(response.body)

        expect(json_response['balance']).to eq(0.0)
      end

      it 'handles very large balance' do
        large_balance = 999999999.99
        service_response = { success: true, balance: large_balance, user: { email: user.email, balance: large_balance } }
        allow(user).to receive(:get_balance_info).and_return(service_response)
        allow(controller).to receive(:current_user).and_return(user)

        get :balance
        json_response = JSON.parse(response.body)

        expect(json_response['balance']).to eq(large_balance)
      end
    end
  end

  describe 'PATCH #update_balance' do
    before { authenticate_as(user) }

    context 'with valid deposit parameters' do
      let(:valid_params) do
        { balance: { operation: 'deposit', amount: 100.0, description: 'Test deposit' } }
      end

      let(:service_response) do
        {
          success: true,
          user: { email: user.email, balance: 600.0 },
          transaction: {
            id: 1,
            amount: 100.0,
            type: 'deposit',
            description: 'Test deposit',
            balance_before: 500.0,
            balance_after: 600.0,
            created_at: Time.current
          }
        }
      end

      before do
        allow(user).to receive(:process_balance_operation!).and_return(service_response)
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'calls current_user.process_balance_operation!' do
        patch :update_balance, params: valid_params

        expect(user).to have_received(:process_balance_operation!)
          .with('deposit', 100.0, description: 'Test deposit')
      end

      it 'passes correct parameters to service' do
        patch :update_balance, params: valid_params

        expect(user).to have_received(:process_balance_operation!) do |operation, amount, options|
          expect(operation).to eq('deposit')
          expect(amount).to eq(100.0)
          expect(options[:description]).to eq('Test deposit')
        end
      end

      it 'returns 200 status on success' do
        patch :update_balance, params: valid_params
        expect(response).to have_http_status(:ok)
      end

      it 'returns updated balance information' do
        patch :update_balance, params: valid_params
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be true
        expect(json_response['user']['balance']).to eq(600.0)
        expect(json_response['transaction']['amount']).to eq(100.0)
      end
    end

    context 'with valid withdrawal parameters' do
      let(:valid_params) do
        { balance: { operation: 'withdraw', amount: 50.0 } }
      end

      let(:service_response) do
        {
          success: true,
          user: { email: user.email, balance: 450.0 },
          transaction: {
            id: 1,
            amount: -50.0,
            type: 'withdrawal',
            description: 'Withdrawal of 50.0',
            balance_before: 500.0,
            balance_after: 450.0,
            created_at: Time.current
          }
        }
      end

      before do
        allow(user).to receive(:process_balance_operation!).and_return(service_response)
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'processes withdrawal correctly' do
        patch :update_balance, params: valid_params

        expect(user).to have_received(:process_balance_operation!)
          .with('withdraw', 50.0, description: nil)
      end

      it 'handles insufficient funds error' do
        insufficient_funds_params = { balance: { operation: 'withdraw', amount: 600.0 } }
        error_response = { success: false, errors: [ 'Insufficient funds' ] }
        allow(user).to receive(:process_balance_operation!).and_return(error_response)

        patch :update_balance, params: insufficient_funds_params

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Insufficient funds')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        { balance: { operation: 'invalid', amount: -50 } }
      end

      let(:error_response) do
        { success: false, errors: [ 'Invalid operation. Use deposit or withdraw' ] }
      end

      before do
        allow(user).to receive(:process_balance_operation!).and_return(error_response)
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'returns 422 status on validation error' do
        patch :update_balance, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns service error messages' do
        patch :update_balance, params: invalid_params
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['errors']).to include('Invalid operation. Use deposit or withdraw')
      end
    end

    context 'with parameter handling' do
      before do
        allow(user).to receive(:process_balance_operation!).and_return(success: true)
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'processes balance_params correctly' do
        params = { balance: { operation: 'deposit', amount: 100.0, description: 'test', extra_param: 'ignored' } }

        patch :update_balance, params: params

        expect(user).to have_received(:process_balance_operation!)
          .with('deposit', 100.0, description: 'test')
      end

      it 'permits operation, amount, description' do
        controller.params = ActionController::Parameters.new({
          balance: { operation: 'deposit', amount: 100.0, description: 'test' }
        })
        result = controller.send(:balance_params)

        expect(result.keys).to contain_exactly('operation', 'amount', 'description')
      end

      it 'handles missing required parameters' do
        post :update_balance, params: { operation: 'deposit' }

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Internal server error')
      end

      it 'handles nil description' do
        params = { balance: { operation: 'deposit', amount: 100.0 } }

        patch :update_balance, params: params

        expect(user).to have_received(:process_balance_operation!)
          .with('deposit', 100.0, description: nil)
      end
    end

    context 'with authorization' do
      let(:other_user) { create(:user, balance: 300.0) }

      it 'only updates current_user balance' do
        allow(controller).to receive(:current_user).and_return(user)
        allow(user).to receive(:process_balance_operation!).and_return(success: true)

        patch :update_balance, params: { balance: { operation: 'deposit', amount: 100.0 } }

        expect(user).to have_received(:process_balance_operation!)
        expect(controller.instance_variable_get(:@current_user)).to eq(user)
      end

      it 'cannot update other user balance' do
        allow(controller).to receive(:current_user).and_return(user)
        allow(user).to receive(:process_balance_operation!).and_return(success: true)
        allow(other_user).to receive(:process_balance_operation!)

        patch :update_balance, params: { balance: { operation: 'deposit', amount: 100.0 } }

        expect(user).to have_received(:process_balance_operation!)
        expect(other_user).not_to have_received(:process_balance_operation!)
      end

      it 'uses authenticated user context' do
        allow(controller).to receive(:current_user).and_return(user)
        allow(user).to receive(:process_balance_operation!).and_return(success: true)

        patch :update_balance, params: { balance: { operation: 'deposit', amount: 100.0 } }

        expect(controller.instance_variable_get(:@current_user)).to eq(user)
      end

      context 'when user A tries to update user B balance' do
        it 'always uses current_user regardless of any parameter manipulation' do
          allow(controller).to receive(:current_user).and_return(user)
          allow(user).to receive(:process_balance_operation!).and_return(success: true)

          patch :update_balance, params: {
            balance: { operation: 'deposit', amount: 100.0 },
            user_id: other_user.id
          }

          expect(user).to have_received(:process_balance_operation!)
          expect(controller.instance_variable_get(:@current_user)).to eq(user)
        end
      end
    end

    context 'with edge cases' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'handles zero amounts' do
        params = { balance: { operation: 'deposit', amount: 0 } }
        error_response = { success: false, errors: [ 'Deposit amount must be positive' ] }
        allow(user).to receive(:process_balance_operation!).and_return(error_response)

        patch :update_balance, params: params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'handles very large amounts' do
        params = { balance: { operation: 'deposit', amount: 999999999.99 } }
        error_response = { success: false, errors: [ 'Deposit amount too large' ] }
        allow(user).to receive(:process_balance_operation!).and_return(error_response)

        patch :update_balance, params: params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'handles service exceptions' do
        params = { balance: { operation: 'deposit', amount: 100.0 } }
        allow(user).to receive(:process_balance_operation!).and_raise(StandardError.new('Service error'))

        patch :update_balance, params: params

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Internal server error')
      end

      it 'handles decimal precision' do
        params = { balance: { operation: 'deposit', amount: 123.456 } }
        service_response = { success: true, user: { email: user.email, balance: 623.46 } }
        allow(user).to receive(:process_balance_operation!).and_return(service_response)

        patch :update_balance, params: params

        expect(user).to have_received(:process_balance_operation!)
          .with('deposit', 123.456, description: nil)
      end

      it 'handles string amounts' do
        params = { balance: { operation: 'deposit', amount: '100.50' } }
        allow(user).to receive(:process_balance_operation!).and_return(success: true)

        patch :update_balance, params: params

        expect(user).to have_received(:process_balance_operation!)
          .with('deposit', '100.50', description: nil)
      end
    end

    context 'without authentication' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        allow(controller).to receive(:authenticate_request).and_call_original
      end

      it 'returns 500 internal server error when current_user is nil' do
        patch :update_balance, params: { balance: { operation: 'deposit', amount: 100.0 } }
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'does not call service methods' do
        allow(user).to receive(:process_balance_operation!)
        patch :update_balance, params: { balance: { operation: 'deposit', amount: 100.0 } }

        expect(user).not_to have_received(:process_balance_operation!)
      end
    end
  end

  describe 'response format consistency' do
    before { authenticate_as(user) }

    it 'maintains consistent success response structure for balance' do
      service_response = { success: true, balance: 500.0, user: { email: user.email, balance: 500.0 } }
      allow(user).to receive(:get_balance_info).and_return(service_response)
      allow(controller).to receive(:current_user).and_return(user)

      get :balance
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('success')
      expect(json_response).to have_key('balance')
      expect(json_response).to have_key('user')
    end

    it 'maintains consistent success response structure for update_balance' do
      service_response = {
        success: true,
        user: { email: user.email, balance: 600.0 },
        transaction: { id: 1, amount: 100.0, type: 'deposit' }
      }
      allow(user).to receive(:process_balance_operation!).and_return(service_response)
      allow(controller).to receive(:current_user).and_return(user)

      patch :update_balance, params: { balance: { operation: 'deposit', amount: 100.0 } }
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('success')
      expect(json_response).to have_key('user')
      expect(json_response).to have_key('transaction')
    end

    it 'maintains consistent error response structure' do
      error_response = { success: false, errors: [ 'Test error' ] }
      allow(user).to receive(:process_balance_operation!).and_return(error_response)
      allow(controller).to receive(:current_user).and_return(user)

      patch :update_balance, params: { balance: { operation: 'invalid', amount: 100.0 } }
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('success')
      expect(json_response).to have_key('errors')
      expect(json_response['errors']).to be_an(Array)
    end
  end
end
