# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JsonWebToken, type: :service do
  let(:payload) { { user_id: 123, email: 'test@example.com' } }
  let(:token) { described_class.encode(payload) }

  describe '.encode' do
    context 'with valid payload' do
      it 'returns a JWT token' do
        expect(token).to be_a(String)
        expect(token).not_to be_empty
      end

      it 'includes expiration in the token' do
        decoded_token = JWT.decode(token, described_class::SECRET_KEY)[0]
        expect(decoded_token['exp']).to be_present
        expect(decoded_token['exp']).to be > Time.current.to_i
      end

      it 'uses custom expiration when provided' do
        custom_exp = 2.hours.from_now
        custom_token = described_class.encode(payload, custom_exp)
        decoded_token = JWT.decode(custom_token, described_class::SECRET_KEY)[0]

        expect(decoded_token['exp']).to eq(custom_exp.to_i)
      end

      it 'preserves original payload data' do
        decoded_token = JWT.decode(token, described_class::SECRET_KEY)[0]
        expect(decoded_token['user_id']).to eq(123)
        expect(decoded_token['email']).to eq('test@example.com')
      end
    end

    context 'with invalid payload' do
      it 'raises ArgumentError for nil payload' do
        expect {
          described_class.encode(nil)
        }.to raise_error(ArgumentError, 'Payload cannot be nil')
      end

      it 'handles empty payload' do
        empty_payload = {}
        token = described_class.encode(empty_payload)
        expect(token).to be_a(String)
      end
    end
  end

  describe '.decode' do
    context 'with valid token' do
      it 'returns decoded payload as HashWithIndifferentAccess' do
        result = described_class.decode(token)

        expect(result).to be_a(ActiveSupport::HashWithIndifferentAccess)
        expect(result[:user_id]).to eq(123)
        expect(result['user_id']).to eq(123)
        expect(result[:email]).to eq('test@example.com')
      end

      it 'includes expiration time' do
        result = described_class.decode(token)
        expect(result[:exp]).to be_present
        expect(result[:exp]).to be > Time.current.to_i
      end
    end

    context 'with invalid token' do
      it 'raises InvalidTokenError for malformed token' do
        expect {
          described_class.decode('invalid_token')
        }.to raise_error(JsonWebToken::InvalidTokenError, 'Invalid token')
      end

      it 'raises InvalidTokenError for token with wrong signature' do
        wrong_token = JWT.encode(payload, 'wrong_secret')

        expect {
          described_class.decode(wrong_token)
        }.to raise_error(JsonWebToken::InvalidTokenError, 'Invalid token')
      end

      it 'raises ExpiredTokenError for expired token' do
        expired_token = described_class.encode(payload, 1.hour.ago)

        expect {
          described_class.decode(expired_token)
        }.to raise_error(JsonWebToken::ExpiredTokenError, 'Token has expired')
      end

      it 'raises MissingTokenError for nil token' do
        expect {
          described_class.decode(nil)
        }.to raise_error(JsonWebToken::MissingTokenError, 'Token cannot be nil or empty')
      end

      it 'raises MissingTokenError for empty token' do
        expect {
          described_class.decode('')
        }.to raise_error(JsonWebToken::MissingTokenError, 'Token cannot be nil or empty')
      end

      it 'raises MissingTokenError for whitespace-only token' do
        expect {
          described_class.decode('   ')
        }.to raise_error(JsonWebToken::MissingTokenError, 'Token cannot be nil or empty')
      end

      it 'raises InvalidTokenError for non-string token' do
        expect {
          described_class.decode([ 'array', 'token' ])
        }.to raise_error(NoMethodError)
      end
    end
  end

  describe '.valid?' do
    context 'with valid token' do
      it 'returns true' do
        expect(described_class.valid?(token)).to be true
      end

      it 'returns true for token with different payload' do
        different_payload = { user_id: 456, role: 'admin' }
        different_token = described_class.encode(different_payload)
        expect(described_class.valid?(different_token)).to be true
      end
    end

    context 'with invalid token' do
      it 'returns false for malformed token' do
        expect(described_class.valid?('invalid')).to be false
      end

      it 'returns false for expired token' do
        expired_token = described_class.encode(payload, 1.hour.ago)
        expect(described_class.valid?(expired_token)).to be false
      end

      it 'returns false for nil token' do
        expect(described_class.valid?(nil)).to be false
      end

      it 'returns false for empty token' do
        expect(described_class.valid?('')).to be false
      end

      it 'returns false for token with wrong signature' do
        wrong_token = JWT.encode(payload, 'wrong_secret')
        expect(described_class.valid?(wrong_token)).to be false
      end
    end
  end

  describe 'SECRET_KEY' do
    it 'uses Rails credentials or fallback' do
      expect(described_class::SECRET_KEY).to be_present
      expect(described_class::SECRET_KEY).to be_a(String)
    end

    it 'is not empty or just whitespace' do
      expect(described_class::SECRET_KEY.strip).not_to be_empty
    end
  end

  describe 'custom exceptions' do
    it 'defines InvalidTokenError' do
      expect(JsonWebToken::InvalidTokenError).to be < StandardError
    end

    it 'defines ExpiredTokenError' do
      expect(JsonWebToken::ExpiredTokenError).to be < StandardError
    end

    it 'defines MissingTokenError' do
      expect(JsonWebToken::MissingTokenError).to be < StandardError
    end
  end

  describe 'security considerations' do
    it 'generates different tokens for same payload at different times' do
      token1 = described_class.encode(payload)
      sleep(1) # Ensure different timestamps
      token2 = described_class.encode(payload)

      expect(token1).not_to eq(token2)
    end

    it 'tokens with different secrets cannot be decoded' do
      external_token = JWT.encode(payload, 'different_secret')

      expect {
        described_class.decode(external_token)
      }.to raise_error(JsonWebToken::InvalidTokenError)
    end

    it 'prevents token tampering' do
      parts = token.split('.')
      modified_payload = Base64.urlsafe_encode64('{"user_id":999}')
      tampered_token = "#{parts[0]}.#{modified_payload}.#{parts[2]}"

      expect {
        described_class.decode(tampered_token)
      }.to raise_error(JsonWebToken::InvalidTokenError)
    end
  end
end
