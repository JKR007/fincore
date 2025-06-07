# frozen_string_literal: true

class JsonWebToken
  class InvalidTokenError < StandardError; end
  class ExpiredTokenError < StandardError; end
  class MissingTokenError < StandardError; end

  SECRET_KEY = Rails.application.credentials.secret_key_base ||
               Rails.application.secret_key_base ||
               "test_secret_key_for_development_and_test_environments_only"

  def self.encode(payload, exp = 24.hours.from_now)
    raise ArgumentError, "Payload cannot be nil" if payload.nil?

    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    raise MissingTokenError, "Token cannot be nil or empty" if token.nil? || token.strip.empty?

    begin
      decoded = JWT.decode(token, SECRET_KEY)[0]
      ActiveSupport::HashWithIndifferentAccess.new(decoded)
    rescue JWT::ExpiredSignature
      raise ExpiredTokenError, "Token has expired"
    rescue JWT::InvalidIatError
      raise InvalidTokenError, "Token issued at claim is invalid"
    rescue JWT::DecodeError, JWT::VerificationError
      raise InvalidTokenError, "Invalid token"
    end
  end

  def self.valid?(token)
    decode(token)
    true
  rescue InvalidTokenError, ExpiredTokenError, MissingTokenError
    false
  end
end
