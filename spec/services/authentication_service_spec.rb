# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthenticationService, type: :service do
  describe '.register' do
    context 'with valid parameters' do
      it 'creates a new user and returns success response' do
        result = described_class.register(email: 'new@example.com')

        expect(result[:success]).to be true
        expect(result[:token]).to be_present
        expect(result[:user][:email]).to eq('new@example.com')
        expect(result[:user][:balance]).to eq(0.0)

        user = User.find_by(email: 'new@example.com')
        expect(user).to be_present
        expect(user.balance).to eq(0.0)
      end

      it 'creates user with custom initial balance' do
        result = described_class.register(
          email: 'rich@example.com',
          initial_balance: 1000.50
        )

        expect(result[:success]).to be true
        expect(result[:user][:balance]).to eq(1000.50)

        user = User.find_by(email: 'rich@example.com')
        expect(user.balance).to eq(1000.50)
      end

      it 'generates a valid JWT token' do
        result = described_class.register(email: 'token@example.com')

        expect(result[:token]).to be_present

        decoded_token = JsonWebToken.decode(result[:token])
        expect(decoded_token[:user_id]).to be_present
        expect(decoded_token[:email]).to eq('token@example.com')
      end

      it 'normalizes email through User model' do
        result = described_class.register(email: 'UPPER@EXAMPLE.COM')

        expect(result[:success]).to be true
        expect(result[:user][:email]).to eq('upper@example.com')
      end

      it 'creates user with zero balance by default' do
        result = described_class.register(email: 'zero@example.com')

        expect(result[:success]).to be true
        expect(result[:user][:balance]).to eq(0.0)
      end
    end

    context 'with invalid parameters' do
      it 'returns failure response for invalid email format' do
        result = described_class.register(email: 'invalid_email')

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Email must be a valid email address')
        expect(result[:token]).to be_nil

        expect(User.find_by(email: 'invalid_email')).to be_nil
      end

      it 'returns failure response for blank email' do
        result = described_class.register(email: '')

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
        expect(result[:token]).to be_nil
      end

      it 'returns failure response for nil email' do
        result = described_class.register(email: nil)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
        expect(result[:token]).to be_nil
      end

      it 'returns failure response for negative initial balance' do
        result = described_class.register(
          email: 'negative@example.com',
          initial_balance: -100.0
        )

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Balance cannot be negative')
        expect(result[:token]).to be_nil
      end

      it 'returns failure response for duplicate email' do
        create(:user, email: 'existing@example.com')

        result = described_class.register(email: 'existing@example.com')

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Email has already been taken')
        expect(result[:token]).to be_nil
      end

      it 'handles database-level duplicate constraint' do
        create(:user, email: 'db_duplicate@example.com')

        instance_double(User, save: false)
        allow(User).to receive(:new).and_raise(ActiveRecord::RecordNotUnique)

        result = described_class.register(email: 'db_duplicate@example.com')

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Email has already been taken')
      end
    end

    context 'with success response' do
      it 'returns expected structure' do
        result = described_class.register(email: 'structure@example.com')

        expect(result).to be_a(Hash)
        expect(result.keys).to contain_exactly(:success, :token, :user)
        expect(result[:user].keys).to contain_exactly(:email, :balance)
      end
    end

    context 'with error response' do
      it 'returns expected structure' do
        result = described_class.register(email: 'invalid')

        expect(result).to be_a(Hash)
        expect(result.keys).to contain_exactly(:success, :errors)
        expect(result[:errors]).to be_an(Array)
      end
    end
  end

  describe '.authenticate' do
    let!(:user) { create(:user, email: 'test@example.com', balance: 250.75) }

    context 'with valid email' do
      it 'returns success response with token and user data' do
        result = described_class.authenticate(email: user.email)

        expect(result[:success]).to be true
        expect(result[:token]).to be_present
        expect(result[:user][:email]).to eq(user.email)
        expect(result[:user][:balance]).to eq(user.balance)
      end

      it 'generates a valid JWT token' do
        result = described_class.authenticate(email: user.email)

        decoded_token = JsonWebToken.decode(result[:token])
        expect(decoded_token[:user_id]).to eq(user.id)
        expect(decoded_token[:email]).to eq(user.email)
      end

      it 'finds user case-sensitively' do
        result = described_class.authenticate(email: user.email.upcase)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('User not found')
      end

      it 'finds user with exact email match' do
        result = described_class.authenticate(email: user.email)

        expect(result[:success]).to be true
        expect(result[:user][:email]).to eq(user.email)
      end
    end

    context 'with invalid email' do
      it 'returns failure response for non-existent user' do
        result = described_class.authenticate(email: 'nonexistent@example.com')

        expect(result[:success]).to be false
        expect(result[:errors]).to include('User not found')
        expect(result[:token]).to be_nil
      end

      it 'returns failure response for blank email' do
        result = described_class.authenticate(email: '')

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Email is required')
        expect(result[:token]).to be_nil
      end

      it 'returns failure response for nil email' do
        result = described_class.authenticate(email: nil)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Email is required')
        expect(result[:token]).to be_nil
      end

      it 'returns failure response for whitespace-only email' do
        result = described_class.authenticate(email: '   ')

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Email is required')
        expect(result[:token]).to be_nil
      end
    end

    context 'with success response' do
      it 'returns expected structure' do
        result = described_class.authenticate(email: user.email)

        expect(result).to be_a(Hash)
        expect(result.keys).to contain_exactly(:success, :token, :user)
        expect(result[:user].keys).to contain_exactly(:email, :balance)
      end
    end

    context 'with error response' do
      it 'returns expected structure' do
        result = described_class.authenticate(email: 'nonexistent@example.com')

        expect(result).to be_a(Hash)
        expect(result.keys).to contain_exactly(:success, :errors)
        expect(result[:errors]).to be_an(Array)
      end
    end
  end

  describe 'private methods' do
    let(:user) { create(:user, email: 'private@example.com', balance: 100.0) }

    describe '.success_response' do
      it 'creates proper response structure' do
        result = described_class.send(:success_response, user)

        expect(result[:success]).to be true
        expect(result[:token]).to be_present
        expect(result[:user]).to be_a(Hash)
      end
    end

    describe '.error_response' do
      it 'handles string error' do
        result = described_class.send(:error_response, 'Single error')

        expect(result[:success]).to be false
        expect(result[:errors]).to eq([ 'Single error' ])
      end

      it 'handles array of errors' do
        errors = [ 'Error 1', 'Error 2' ]
        result = described_class.send(:error_response, errors)

        expect(result[:success]).to be false
        expect(result[:errors]).to eq(errors)
      end
    end

    describe '.user_data' do
      it 'returns user data hash' do
        result = described_class.send(:user_data, user)

        expect(result).to eq({
                               email: user.email,
                               balance: user.balance
                             })
      end
    end
  end

  describe 'integration scenarios' do
    it 'can register and then authenticate the same user' do
      register_result = described_class.register(email: 'integration@example.com', initial_balance: 500.0)
      expect(register_result[:success]).to be true

      auth_result = described_class.authenticate(email: 'integration@example.com')
      expect(auth_result[:success]).to be true
      expect(auth_result[:user][:balance]).to eq(500.0)
    end

    it 'handles concurrent registration attempts gracefully' do
      email = 'concurrent@example.com'

      result1 = described_class.register(email: email)
      expect(result1[:success]).to be true

      result2 = described_class.register(email: email)
      expect(result2[:success]).to be false
      expect(result2[:errors]).to include('Email has already been taken')
    end
  end
end
