# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::TransfersController, type: :controller do
  let(:sender) { create(:user, balance: 1000.0) }
  let(:recipient) { create(:user, balance: 200.0) }

  describe 'POST #create' do
    before { authenticate_as(sender) }

    context 'with valid parameters' do
      let(:valid_params) do
        { transfer: { to_email: recipient.email, amount: 150.0, description: 'Payment for services' } }
      end

      let(:service_response) do
        {
          success: true,
          transfer: {
            amount: 150.0,
            from_user: { email: sender.email, balance: 850.0 },
            to_user: { email: recipient.email, balance: 350.0 },
            description: 'Payment for services'
          },
          transactions: [
            {
              id: 1,
              amount: -150.0,
              type: 'transfer_out',
              description: 'Payment for services',
              balance_before: 1000.0,
              balance_after: 850.0,
              created_at: Time.current
            },
            {
              id: 2,
              amount: 150.0,
              type: 'transfer_in',
              description: 'Payment for services',
              balance_before: 200.0,
              balance_after: 350.0,
              created_at: Time.current
            }
          ]
        }
      end

      before do
        allow(sender).to receive(:transfer_to_email!).and_return(service_response)
        allow(controller).to receive(:current_user).and_return(sender)
      end

      it 'calls current_user.transfer_to_email!' do
        post :create, params: valid_params

        expect(sender).to have_received(:transfer_to_email!)
          .with(recipient.email, 150.0, description: 'Payment for services')
      end

      it 'passes correct parameters to transfer method' do
        post :create, params: valid_params

        expect(sender).to have_received(:transfer_to_email!) do |to_email, amount, options|
          expect(to_email).to eq(recipient.email)
          expect(amount).to eq(150.0)
          expect(options[:description]).to eq('Payment for services')
        end
      end

      it 'returns 201 status on success' do
        post :create, params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'returns transfer details' do
        post :create, params: valid_params
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be true
        expect(json_response['transfer']['amount']).to eq(150.0)
        expect(json_response['transfer']['from_user']['email']).to eq(sender.email)
        expect(json_response['transfer']['to_user']['email']).to eq(recipient.email)
      end

      it 'returns transaction information' do
        post :create, params: valid_params
        json_response = JSON.parse(response.body)

        expect(json_response['transactions']).to be_an(Array)
        expect(json_response['transactions'].size).to eq(2)
        expect(json_response['transactions'][0]['type']).to eq('transfer_out')
        expect(json_response['transactions'][1]['type']).to eq('transfer_in')
      end

      it 'handles transfer without description' do
        params_without_description = { transfer: { to_email: recipient.email, amount: 100.0 } }
        allow(sender).to receive(:transfer_to_email!).and_return(service_response)

        post :create, params: params_without_description

        expect(sender).to have_received(:transfer_to_email!)
          .with(recipient.email, 100.0, description: nil)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        { transfer: { to_email: 'nonexistent@example.com', amount: 2000.0 } }
      end

      let(:error_response) do
        { success: false, errors: [ 'Recipient user not found' ] }
      end

      before do
        allow(sender).to receive(:transfer_to_email!).and_return(error_response)
        allow(controller).to receive(:current_user).and_return(sender)
      end

      it 'returns 422 status on validation error' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns service error messages' do
        post :create, params: invalid_params
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['errors']).to include('Recipient user not found')
      end

      it 'handles insufficient funds' do
        insufficient_funds_params = { transfer: { to_email: recipient.email, amount: 1500.0 } }
        error_response = { success: false, errors: [ 'Insufficient funds for transfer' ] }
        allow(sender).to receive(:transfer_to_email!).and_return(error_response)

        post :create, params: insufficient_funds_params

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Insufficient funds for transfer')
      end

      it 'handles invalid recipient' do
        invalid_recipient_params = { transfer: { to_email: 'invalid@example.com', amount: 100.0 } }
        error_response = { success: false, errors: [ 'Recipient user not found' ] }
        allow(sender).to receive(:transfer_to_email!).and_return(error_response)

        post :create, params: invalid_recipient_params

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Recipient user not found')
      end
    end

    context 'with parameter handling' do
      before do
        allow(sender).to receive(:transfer_to_email!).and_return(success: true)
        allow(controller).to receive(:current_user).and_return(sender)
      end

      it 'processes transfer_params correctly' do
        params = { transfer: { to_email: recipient.email, amount: 100.0, description: 'test', extra_param: 'ignored' } }

        post :create, params: params

        expect(sender).to have_received(:transfer_to_email!)
          .with(recipient.email, 100.0, description: 'test')
      end

      it 'permits to_email, amount, description' do
        controller.params = ActionController::Parameters.new({
          transfer: { to_email: recipient.email, amount: 100.0, description: 'test' }
        })
        result = controller.send(:transfer_params)

        expect(result.keys).to contain_exactly('to_email', 'amount', 'description')
      end

      it 'handles missing required parameters' do
        allow(sender).to receive(:transfer_to_email!).and_raise(StandardError.new('Missing parameters'))

        post :create, params: { to_email: recipient.email }

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Internal server error')
      end

      it 'handles missing to_email' do
        params = { transfer: { amount: 100.0 } }

        post :create, params: params

        expect(sender).to have_received(:transfer_to_email!)
          .with(nil, 100.0, description: nil)
      end

      it 'handles missing amount' do
        params = { transfer: { to_email: recipient.email } }

        post :create, params: params

        expect(sender).to have_received(:transfer_to_email!)
          .with(recipient.email, nil, description: nil)
      end
    end

    context 'with authorization' do
      it 'only allows transfers from current_user' do
        allow(controller).to receive(:current_user).and_return(sender)
        allow(sender).to receive(:transfer_to_email!).and_return(success: true)

        post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }

        expect(sender).to have_received(:transfer_to_email!)
        expect(controller.instance_variable_get(:@current_user)).to eq(sender)
      end

      it 'cannot initiate transfers for other users' do
        other_user = create(:user, balance: 500.0)
        allow(controller).to receive(:current_user).and_return(sender)
        allow(sender).to receive(:transfer_to_email!).and_return(success: true)
        allow(other_user).to receive(:transfer_to_email!)

        post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }

        expect(sender).to have_received(:transfer_to_email!)
        expect(other_user).not_to have_received(:transfer_to_email!)
      end

      it 'uses authenticated user as sender' do
        allow(controller).to receive(:current_user).and_return(sender)
        allow(sender).to receive(:transfer_to_email!).and_return(success: true)

        post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }

        expect(controller.instance_variable_get(:@current_user)).to eq(sender)
      end

      context 'when user A tries to transfer for user B' do
        let(:other_user) { create(:user, balance: 500.0) }

        it 'uses current_user as transfer source' do
          allow(controller).to receive(:current_user).and_return(sender)
          allow(sender).to receive(:transfer_to_email!).and_return(success: true)

          post :create, params: {
            transfer: { to_email: recipient.email, amount: 100.0 },
            from_user_id: other_user.id
          }

          expect(sender).to have_received(:transfer_to_email!)
          expect(controller.instance_variable_get(:@current_user)).to eq(sender)
        end

        it 'ignores any attempts to specify different sender' do
          allow(controller).to receive(:current_user).and_return(sender)
          allow(sender).to receive(:transfer_to_email!).and_return(success: true)

          post :create, params: {
            transfer: {
              from_email: other_user.email,
              to_email: recipient.email,
              amount: 100.0
            }
          }

          expect(sender).to have_received(:transfer_to_email!)
          expect(controller.instance_variable_get(:@current_user)).to eq(sender)
        end
      end
    end

    context 'with edge cases' do
      before do
        allow(controller).to receive(:current_user).and_return(sender)
      end

      it 'handles self-transfer attempts' do
        params = { transfer: { to_email: sender.email, amount: 100.0 } }
        error_response = { success: false, errors: [ 'Cannot transfer to the same user' ] }
        allow(sender).to receive(:transfer_to_email!).and_return(error_response)

        post :create, params: params

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Cannot transfer to the same user')
      end

      it 'handles very large amounts' do
        params = { transfer: { to_email: recipient.email, amount: 999999999.99 } }
        error_response = { success: false, errors: [ 'Transfer amount too large' ] }
        allow(sender).to receive(:transfer_to_email!).and_return(error_response)

        post :create, params: params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'handles decimal precision' do
        params = { transfer: { to_email: recipient.email, amount: 123.456 } }
        allow(sender).to receive(:transfer_to_email!).and_return(success: true)

        post :create, params: params

        expect(sender).to have_received(:transfer_to_email!)
          .with(recipient.email, 123.456, description: nil)
      end

      it 'handles email normalization' do
        params = { transfer: { to_email: recipient.email.upcase, amount: 100.0 } }
        allow(sender).to receive(:transfer_to_email!).and_return(success: true)

        post :create, params: params

        expect(sender).to have_received(:transfer_to_email!)
          .with(recipient.email.upcase, 100.0, description: nil)
      end

      it 'handles string amounts' do
        params = { transfer: { to_email: recipient.email, amount: '150.50' } }
        allow(sender).to receive(:transfer_to_email!).and_return(success: true)

        post :create, params: params

        expect(sender).to have_received(:transfer_to_email!)
          .with(recipient.email, '150.50', description: nil)
      end

      it 'handles zero amounts' do
        params = { transfer: { to_email: recipient.email, amount: 0 } }
        error_response = { success: false, errors: [ 'Transfer amount must be positive' ] }
        allow(sender).to receive(:transfer_to_email!).and_return(error_response)

        post :create, params: params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'handles negative amounts' do
        params = { transfer: { to_email: recipient.email, amount: -100.0 } }
        error_response = { success: false, errors: [ 'Transfer amount must be positive' ] }
        allow(sender).to receive(:transfer_to_email!).and_return(error_response)

        post :create, params: params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with service integration' do
      before do
        allow(controller).to receive(:current_user).and_return(sender)
      end

      it 'delegates to user transfer method' do
        allow(sender).to receive(:transfer_to_email!).and_return(success: true)

        post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }

        expect(sender).to have_received(:transfer_to_email!)
      end

      it 'handles successful transfer response' do
        success_response = {
          success: true,
          transfer: { amount: 100.0, from_user: { email: sender.email }, to_user: { email: recipient.email } }
        }
        allow(sender).to receive(:transfer_to_email!).and_return(success_response)

        post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be true
        expect(json_response['transfer']['amount']).to eq(100.0)
      end

      it 'handles failed transfer response' do
        failed_response = { success: false, errors: [ 'Transfer failed' ] }
        allow(sender).to receive(:transfer_to_email!).and_return(failed_response)

        post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end

      context 'when service raises exception' do
        before do
          allow(sender).to receive(:transfer_to_email!).and_raise(StandardError.new('Service error'))
        end

        it 'lets exception bubble up to base controller' do
          post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }

          expect(response).to have_http_status(:internal_server_error)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Internal server error')
        end
      end
    end

    context 'without authentication' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        allow(controller).to receive(:authenticate_request).and_call_original
      end

      it 'returns 500 internal server error when current_user is nil' do
        post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'does not call service methods' do
        allow(sender).to receive(:transfer_to_email!)

        post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }

        expect(sender).not_to have_received(:transfer_to_email!)
      end

      it 'returns internal server error message' do
        post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['errors']).to include('Internal server error')
      end
    end
  end

  describe 'response format consistency' do
    before { authenticate_as(sender) }

    it 'maintains consistent success response structure' do
      success_response = {
        success: true,
        transfer: {
          amount: 100.0,
          from_user: { email: sender.email, balance: 900.0 },
          to_user: { email: recipient.email, balance: 300.0 },
          description: 'Test transfer'
        },
        transactions: [
          { id: 1, amount: -100.0, type: 'transfer_out' },
          { id: 2, amount: 100.0, type: 'transfer_in' }
        ]
      }
      allow(sender).to receive(:transfer_to_email!).and_return(success_response)
      allow(controller).to receive(:current_user).and_return(sender)

      post :create, params: { transfer: { to_email: recipient.email, amount: 100.0 } }
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('success')
      expect(json_response).to have_key('transfer')
      expect(json_response).to have_key('transactions')
      expect(json_response['transactions']).to be_an(Array)
    end

    it 'maintains consistent error response structure' do
      error_response = { success: false, errors: [ 'Test error' ] }
      allow(sender).to receive(:transfer_to_email!).and_return(error_response)
      allow(controller).to receive(:current_user).and_return(sender)

      post :create, params: { transfer: { to_email: 'invalid@example.com', amount: 100.0 } }
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('success')
      expect(json_response).to have_key('errors')
      expect(json_response['errors']).to be_an(Array)
    end
  end

  describe 'transfer amount edge cases' do
    before do
      authenticate_as(sender)
      allow(controller).to receive(:current_user).and_return(sender)
    end

    it 'handles transfer of entire balance' do
      params = { transfer: { to_email: recipient.email, amount: 1000.0 } }
      success_response = {
        success: true,
        transfer: {
          amount: 1000.0,
          from_user: { email: sender.email, balance: 0.0 },
          to_user: { email: recipient.email, balance: 1200.0 }
        }
      }
      allow(sender).to receive(:transfer_to_email!).and_return(success_response)

      post :create, params: params
      json_response = JSON.parse(response.body)

      expect(json_response['success']).to be true
      expect(json_response['transfer']['from_user']['balance']).to eq(0.0)
    end

    it 'handles transfer amount exceeding balance' do
      params = { transfer: { to_email: recipient.email, amount: 1100.0 } }
      error_response = { success: false, errors: [ 'Insufficient funds for transfer' ] }
      allow(sender).to receive(:transfer_to_email!).and_return(error_response)

      post :create, params: params

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to include('Insufficient funds for transfer')
    end
  end
end
