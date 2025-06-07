module AuthenticationHelpers
  def jwt_token_for(user)
    JsonWebToken.encode(user_id: user.id, email: user.email)
  end

  def auth_headers_for(user)
    { 'Authorization' => "Bearer #{jwt_token_for(user)}", 'Content-Type' => 'application/json' }
  end

  def invalid_auth_headers
    { 'Authorization' => 'Bearer invalid_token', 'Content-Type' => 'application/json' }
  end

  def no_auth_headers
    { 'Content-Type' => 'application/json' }
  end

  def authenticate_as(user)
    allow(JsonWebToken).to receive(:decode).and_return(user_id: user.id, email: user.email)
    @request.headers.merge!(auth_headers_for(user))
  end

  def create_authenticated_user(attributes = {})
    user = create(:user, attributes)
    token = jwt_token_for(user)
    { user: user, token: token, headers: auth_headers_for(user) }
  end

  def expect_unauthorized_response
    expect(response).to have_http_status(:unauthorized)
    expect(json_response['errors']).to include('Unauthorized')
  end

  def expect_forbidden_response
    expect(response).to have_http_status(:forbidden)
    expect(json_response['errors']).to include('Forbidden')
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
