# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::AuthenticationController, type: :controller do
  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_params) { { user: { email: 'test@example.com', initial_balance: 100.0 } } }
      let(:service_response) do
        {
          success: true,
          token: 'jwt_token',
          user: { email: 'test@example.com', balance: 100.0 }
        }
      end

      before do
        allow(AuthenticationService).to receive(:register).and_return(service_response)
      end

      it 'calls AuthenticationService.register with correct params' do
        post :create, params: valid_params

        expect(AuthenticationService).to have_received(:register)
          .with(email: 'test@example.com', initial_balance: '100.0')
      end

      it 'returns 201 status on success' do
        post :create, params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'returns proper JSON structure' do
        post :create, params: valid_params
        json_response = JSON.parse(response.body)

        expect(json_response.keys).to contain_exactly('success', 'token', 'user')
        expect(json_response['success']).to be true
        expect(json_response['token']).to eq('jwt_token')
        expect(json_response['user']['email']).to eq('test@example.com')
      end

      it 'handles registration without initial_balance' do
        params_without_balance = { user: { email: 'test@example.com' } }
        allow(AuthenticationService).to receive(:register).and_return(service_response)

        post :create, params: params_without_balance

        expect(AuthenticationService).to have_received(:register)
          .with(email: 'test@example.com')
      end

      it 'symbolizes keys properly' do
        post :create, params: valid_params

        expect(AuthenticationService).to have_received(:register) do |args|
          expect(args.keys).to all(be_a(Symbol))
        end
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { { user: { email: 'invalid' } } }
      let(:error_response) do
        {
          success: false,
          errors: [ 'Email must be a valid email address' ]
        }
      end

      before do
        allow(AuthenticationService).to receive(:register).and_return(error_response)
      end

      it 'returns 422 status on validation error' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error messages' do
        post :create, params: invalid_params
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['errors']).to include('Email must be a valid email address')
      end

      it 'does not include token in error response' do
        post :create, params: invalid_params
        json_response = JSON.parse(response.body)

        expect(json_response).not_to have_key('token')
      end
    end

    context 'with parameter handling' do
      it 'processes registration_params correctly' do
        params = { user: { email: 'test@example.com', initial_balance: 500.0, extra_param: 'ignored' } }
        allow(AuthenticationService).to receive(:register).and_return(success: true)

        post :create, params: params

        expect(AuthenticationService).to have_received(:register)
          .with(email: 'test@example.com', initial_balance: '500.0')
      end

      it 'handles missing user parameter' do
        post :create, params: { email: 'test@example.com' }

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Internal server error')
      end

      it 'permits only allowed parameters' do
        params = { user: { email: 'test@example.com', initial_balance: 100.0 } }
        controller.params = ActionController::Parameters.new(params)

        result = controller.send(:registration_params)
        expect(result.keys).to contain_exactly(:email, :initial_balance)
      end
    end

    context 'with edge cases' do
      it 'handles service layer exceptions' do
        allow(AuthenticationService).to receive(:register).and_raise(StandardError.new('Service error'))

        post :create, params: { user: { email: 'test@example.com' } }

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Internal server error')
      end

      it 'handles very large initial balance' do
        params = { user: { email: 'test@example.com', initial_balance: 999999999.99 } }
        allow(AuthenticationService).to receive(:register).and_return(success: true)

        post :create, params: params

        expect(AuthenticationService).to have_received(:register)
          .with(email: 'test@example.com', initial_balance: '999999999.99')
      end

      it 'handles negative initial balance' do
        params = { user: { email: 'test@example.com', initial_balance: -100.0 } }
        error_response = { success: false, errors: [ 'Balance cannot be negative' ] }
        allow(AuthenticationService).to receive(:register).and_return(error_response)

        post :create, params: params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST #login' do
    let(:existing_user) { create(:user, email: 'existing@example.com') }

    context 'with valid email' do
      let(:valid_params) { { user: { email: existing_user.email } } }
      let(:service_response) do
        {
          success: true,
          token: 'jwt_token',
          user: { email: existing_user.email, balance: existing_user.balance }
        }
      end

      before do
        allow(AuthenticationService).to receive(:authenticate).and_return(service_response)
      end

      it 'calls AuthenticationService.authenticate' do
        post :login, params: valid_params

        expect(AuthenticationService).to have_received(:authenticate)
          .with(email: existing_user.email)
      end

      it 'returns 200 status' do
        post :login, params: valid_params
        expect(response).to have_http_status(:ok)
      end

      it 'returns user data and token' do
        post :login, params: valid_params
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be true
        expect(json_response['token']).to eq('jwt_token')
        expect(json_response['user']['email']).to eq(existing_user.email)
      end
    end

    context 'with invalid email' do
      let(:invalid_params) { { user: { email: 'nonexistent@example.com' } } }
      let(:error_response) do
        {
          success: false,
          errors: [ 'User not found' ]
        }
      end

      before do
        allow(AuthenticationService).to receive(:authenticate).and_return(error_response)
      end

      it 'returns 401 status' do
        post :login, params: invalid_params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns authentication error' do
        post :login, params: invalid_params
        json_response = JSON.parse(response.body)

        expect(json_response['success']).to be false
        expect(json_response['errors']).to include('User not found')
      end
    end

    context 'with parameter handling' do
      it 'processes login_params correctly' do
        params = { user: { email: 'test@example.com', extra_param: 'ignored' } }
        allow(AuthenticationService).to receive(:authenticate).and_return(success: true)

        post :login, params: params

        expect(AuthenticationService).to have_received(:authenticate)
          .with(email: 'test@example.com')
      end

      it 'handles missing email parameter' do
        params = { user: { password: 'ignored' } }

        post :login, params: params

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Internal server error')
      end

      it 'permits only email parameter' do
        controller.params = ActionController::Parameters.new({ user: { email: 'test@example.com' } })
        result = controller.send(:login_params)

        expect(result.keys).to eq([ :email ])
      end
    end

    context 'with edge cases' do
      it 'handles blank email' do
        params = { user: { email: '' } }
        error_response = { success: false, errors: [ 'Email is required' ] }
        allow(AuthenticationService).to receive(:authenticate).and_return(error_response)

        post :login, params: params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'handles email with whitespace' do
        params = { user: { email: '  test@example.com  ' } }
        allow(AuthenticationService).to receive(:authenticate).and_return(success: true)

        post :login, params: params

        expect(AuthenticationService).to have_received(:authenticate)
          .with(email: '  test@example.com  ')
      end
    end
  end

  describe 'authentication skipping' do
    it 'allows create action without authentication' do
      allow(AuthenticationService).to receive(:register).and_return(success: true)

      post :create, params: { user: { email: 'test@example.com' } }

      expect(response).not_to have_http_status(:unauthorized)
    end

    it 'allows login action without authentication' do
      allow(AuthenticationService).to receive(:authenticate).and_return(success: true)

      post :login, params: { user: { email: 'test@example.com' } }

      expect(response).not_to have_http_status(:unauthorized)
    end

    it 'does not set current_user for public actions' do
      allow(AuthenticationService).to receive(:register).and_return(success: true)

      post :create, params: { user: { email: 'test@example.com' } }

      expect(controller.instance_variable_get(:@current_user)).to be_nil
    end
  end

  describe 'response format consistency' do
    it 'maintains consistent success response structure' do
      allow(AuthenticationService).to receive(:register).and_return({
        success: true,
        token: 'token',
        user: { email: 'test@example.com', balance: 0.0 }
      })

      post :create, params: { user: { email: 'test@example.com' } }
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('success')
      expect(json_response).to have_key('token')
      expect(json_response).to have_key('user')
    end

    it 'maintains consistent error response structure' do
      allow(AuthenticationService).to receive(:register).and_return({
        success: false,
        errors: [ 'Test error' ]
      })

      post :create, params: { user: { email: 'invalid' } }
      json_response = JSON.parse(response.body)

      expect(json_response).to have_key('success')
      expect(json_response).to have_key('errors')
      expect(json_response['errors']).to be_an(Array)
    end
  end
end
