# frozen_string_literal: true

class AuthenticationService
  class << self
    def register(email:, initial_balance: 0.0)
      user = User.new(email: email, balance: initial_balance)

      user.save ? success_response(user) : error_response(user.errors.full_messages)
    rescue ActiveRecord::RecordNotUnique
      error_response("Email has already been taken")
    end

    def authenticate(email:)
      return error_response([ "Email is required" ]) if email.blank?

      user = User.find_by(email: email)
      user ? success_response(user) : error_response("User not found")
    end

    private

    def success_response(user)
      token = JsonWebToken.encode(user_id: user.id, email: user.email)

      { success: true, token:, user: user_data(user) }
    end

    def error_response(errors)
      { success: false, errors: Array(errors) }
    end

    def user_data(user)
      { email: user.email, balance: user.balance }
    end
  end
end
