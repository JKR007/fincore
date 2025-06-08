# Fincore API Documentation

Complete API reference with curl examples for the Fincore Digital Wallet API.

## Base Information

### Base URL
```
http://localhost:3000/api/v1
```

### Authentication
Most endpoints require a JWT token in the Authorization header:
```
Authorization: Bearer <your_jwt_token>
```

### Content Type
All requests should include:
```
Content-Type: application/json
```

## HTTP Status Codes

| Code | Status | Description |
|------|--------|-------------|
| 200 | OK | Request successful |
| 201 | Created | Resource created successfully |
| 401 | Unauthorized | Invalid or missing authentication |
| 404 | Not Found | Resource not found |
| 422 | Unprocessable Entity | Validation errors |
| 500 | Internal Server Error | Server error |

## Response Format

### Success Response
```json
{
  "success": true,
  "data": { ... },
  "user": { ... },
  "transaction": { ... }
}
```

### Error Response
```json
{
  "success": false,
  "errors": ["Error message here"]
}
```

## Balance Operations

The `/profile/balance` endpoint handles both deposits and withdrawals using the `operation` parameter.

### Supported Operations
| Operation | Description | Effect |
|-----------|-------------|---------|
| `deposit` | Add money to account | Increases balance |
| `withdraw` | Remove money from account | Decreases balance (prevents insufficient funds) |

### Common Validation Rules
- Amount must be positive (> 0)
- Maximum amount: 1,000,000
- Description is optional
- Operation must be exactly "deposit" or "withdraw"

---

- Replace `http://localhost:3000` with your actual API URL
- Replace JWT tokens with actual tokens from login/register responses
- All amounts are in decimal format with up to 2 decimal places (e.g., 100.50)
- Maximum transaction amount is 1,000,000
- Tokens expire after 24 hours by default
- Email addresses are case-insensitive and automatically normalized
- All monetary values use precision decimal handling for accuracy
- Transfer operations are atomic and thread-safe

---

## 1. User Registration

Register a new user with email and optional initial balance.

### Endpoint
```
POST /api/v1/auth/register
```

### Request Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| user.email | string | Yes | Valid email address |
| user.initial_balance | decimal | No | Starting balance (default: 0.0) |

### Register with Initial Balance
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "alice@example.com",
      "initial_balance": 1000.50
    }
  }'
```

**Response (201 Created):**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwiZXhwIjoxNzA2ODM5NDcwfQ.abc123",
  "user": {
    "email": "alice@example.com",
    "balance": 1000.5
  }
}
```

### Register with Zero Balance (Default)
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "bob@example.com"
    }
  }'
```

**Response (201 Created):**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoyLCJlbWFpbCI6ImJvYkBleGFtcGxlLmNvbSIsImV4cCI6MTcwNjgzOTQ3MH0.def456",
  "user": {
    "email": "bob@example.com",
    "balance": 0.0
  }
}
```

### Registration Error Examples

#### Invalid Email Format
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "invalid_email"
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Email must be a valid email address"]
}
```

#### Negative Initial Balance
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "negative@example.com",
      "initial_balance": -100.0
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Balance must be greater than or equal to 0"]
}
```

#### Duplicate Email
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "alice@example.com"
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Email has already been taken"]
}
```

---

## 2. User Login

Login with existing user email to get a fresh JWT token.

### Endpoint
```
POST /api/v1/auth/login
```

### Request Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| user.email | string | Yes | Registered email address |

### Successful Login
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "alice@example.com"
    }
  }'
```

**Response (200 OK):**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwiZXhwIjoxNzA2ODM5NDcwfQ.xyz789",
  "user": {
    "email": "alice@example.com",
    "balance": 1000.5
  }
}
```

### Login Error Examples

#### Non-existent User
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "nonexistent@example.com"
    }
  }'
```

**Response (401 Unauthorized):**
```json
{
  "success": false,
  "errors": ["User not found"]
}
```

#### Blank Email
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": ""
    }
  }'
```

**Response (401 Unauthorized):**
```json
{
  "success": false,
  "errors": ["Email is required"]
}
```

---

## 3. Check Balance

Get the current user's balance and account information.

### Endpoint
```
GET /api/v1/profile/balance
```

### Request Headers
| Header | Value |
|--------|-------|
| Authorization | Bearer {jwt_token} |

### Successful Balance Check
```bash
curl -X GET http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json"
```

**Response (200 OK):**
```json
{
  "success": true,
  "balance": 1000.5,
  "user": {
    "email": "alice@example.com",
    "balance": 1000.5
  }
}
```

### Balance Check Error Examples

#### Missing Authentication
```bash
curl -X GET http://localhost:3000/api/v1/profile/balance \
  -H "Content-Type: application/json"
```

**Response (401 Unauthorized):**
```json
{
  "success": false,
  "errors": ["Unauthorized"]
}
```

#### Invalid Token
```bash
curl -X GET http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer invalid_token" \
  -H "Content-Type: application/json"
```

**Response (401 Unauthorized):**
```json
{
  "success": false,
  "errors": ["Unauthorized"]
}
```

---

## 4. Deposit Money

Add money to the current user's account.

### Endpoint
```
PATCH /api/v1/profile/balance
```

### Request Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| balance.operation | string | Yes | Must be "deposit" |
| balance.amount | decimal | Yes | Amount to deposit (positive) |
| balance.description | string | No | Optional description |

### Deposit with Description
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "balance": {
      "operation": "deposit",
      "amount": 250.75,
      "description": "Salary deposit"
    }
  }'
```

**Response (200 OK):**
```json
{
  "success": true,
  "user": {
    "email": "alice@example.com",
    "balance": 1251.25
  },
  "transaction": {
    "id": 1,
    "amount": 250.75,
    "type": "deposit",
    "description": "Salary deposit",
    "balance_before": 1000.5,
    "balance_after": 1251.25,
    "created_at": "2024-06-08T10:30:00.000Z"
  }
}
```

### Deposit without Description
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "balance": {
      "operation": "deposit",
      "amount": 100.0
    }
  }'
```

**Response (200 OK):**
```json
{
  "success": true,
  "user": {
    "email": "alice@example.com",
    "balance": 1351.25
  },
  "transaction": {
    "id": 2,
    "amount": 100.0,
    "type": "deposit",
    "description": "Deposit of 100.0",
    "balance_before": 1251.25,
    "balance_after": 1351.25,
    "created_at": "2024-06-08T10:35:00.000Z"
  }
}
```

### Deposit Error Examples

#### Negative Amount
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "balance": {
      "operation": "deposit",
      "amount": -50.0
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Deposit amount must be positive"]
}
```

#### Zero Amount
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "balance": {
      "operation": "deposit",
      "amount": 0
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Deposit amount must be positive"]
}
```

#### Amount Too Large
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "balance": {
      "operation": "deposit",
      "amount": 2000000
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Deposit amount too large"]
}
```

---

## 5. Withdraw Money

Remove money from the current user's account.

### Endpoint
```
PATCH /api/v1/profile/balance
```

### Request Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| balance.operation | string | Yes | Must be "withdraw" |
| balance.amount | decimal | Yes | Amount to withdraw (positive) |
| balance.description | string | No | Optional description |

### Withdraw with Description
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "balance": {
      "operation": "withdraw",
      "amount": 150.0,
      "description": "ATM withdrawal"
    }
  }'
```

**Response (200 OK):**
```json
{
  "success": true,
  "user": {
    "email": "alice@example.com",
    "balance": 1201.25
  },
  "transaction": {
    "id": 3,
    "amount": -150.0,
    "type": "withdrawal",
    "description": "ATM withdrawal",
    "balance_before": 1351.25,
    "balance_after": 1201.25,
    "created_at": "2024-06-08T10:40:00.000Z"
  }
}
```

### Withdraw Entire Balance
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoyLCJlbWFpbCI6ImJvYkBleGFtcGxlLmNvbSJ9.abc456" \
  -H "Content-Type: application/json" \
  -d '{
    "balance": {
      "operation": "withdraw",
      "amount": 100.0
    }
  }'
```

### Withdraw Error Examples

#### Insufficient Funds
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoyLCJlbWFpbCI6ImJvYkBleGFtcGxlLmNvbSJ9.abc456" \
  -H "Content-Type: application/json" \
  -d '{
    "balance": {
      "operation": "withdraw",
      "amount": 500.0
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Insufficient funds"]
}
```

#### Invalid Operation
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "balance": {
      "operation": "invalid_operation",
      "amount": 100.0
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Invalid operation. Use deposit or withdraw"]
}
```

---

## 6. Transfer Money

Transfer money from the current user to another user by email.

### Endpoint
```
POST /api/v1/transfers
```

### Request Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| transfer.to_email | string | Yes | Recipient's email address |
| transfer.amount | decimal | Yes | Amount to transfer (positive) |
| transfer.description | string | No | Optional description |

### Transfer with Description
```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "transfer": {
      "to_email": "bob@example.com",
      "amount": 300.0,
      "description": "Payment for services"
    }
  }'
```

**Response (201 Created):**
```json
{
  "success": true,
  "transfer": {
    "amount": 300.0,
    "from_user": {
      "email": "alice@example.com",
      "balance": 901.25
    },
    "to_user": {
      "email": "bob@example.com",
      "balance": 300.0
    },
    "description": "Payment for services"
  },
  "transactions": [
    {
      "id": 4,
      "amount": -300.0,
      "type": "transfer_out",
      "description": "Payment for services",
      "balance_before": 1201.25,
      "balance_after": 901.25,
      "created_at": "2024-06-08T10:45:00.000Z"
    },
    {
      "id": 5,
      "amount": 300.0,
      "type": "transfer_in",
      "description": "Payment for services",
      "balance_before": 0.0,
      "balance_after": 300.0,
      "created_at": "2024-06-08T10:45:00.000Z"
    }
  ]
}
```

### Transfer without Description
```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "transfer": {
      "to_email": "bob@example.com",
      "amount": 150.0
    }
  }'
```

**Response (201 Created):**
```json
{
  "success": true,
  "transfer": {
    "amount": 150.0,
    "from_user": {
      "email": "alice@example.com",
      "balance": 751.25
    },
    "to_user": {
      "email": "bob@example.com",
      "balance": 450.0
    },
    "description": "Transfer to bob@example.com"
  },
  "transactions": [
    {
      "id": 6,
      "amount": -150.0,
      "type": "transfer_out",
      "description": "Transfer to bob@example.com",
      "balance_before": 901.25,
      "balance_after": 751.25,
      "created_at": "2024-06-08T10:50:00.000Z"
    },
    {
      "id": 7,
      "amount": 150.0,
      "type": "transfer_in",
      "description": "Transfer from alice@example.com",
      "balance_before": 300.0,
      "balance_after": 450.0,
      "created_at": "2024-06-08T10:50:00.000Z"
    }
  ]
}
```

### Transfer Error Examples

#### Insufficient Funds
```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "transfer": {
      "to_email": "bob@example.com",
      "amount": 1000.0
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Insufficient funds for transfer"]
}
```

#### Non-existent Recipient
```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "transfer": {
      "to_email": "nonexistent@example.com",
      "amount": 100.0
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Recipient user not found"]
}
```

#### Self Transfer
```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "transfer": {
      "to_email": "alice@example.com",
      "amount": 100.0
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Cannot transfer to the same user"]
}
```

#### Invalid Amount
```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIn0.xyz789" \
  -H "Content-Type: application/json" \
  -d '{
    "transfer": {
      "to_email": "bob@example.com",
      "amount": -50.0
    }
  }'
```

**Response (422 Unprocessable Entity):**
```json
{
  "success": false,
  "errors": ["Transfer amount must be positive"]
}
```

---

## 7. Complete User Journey Example

Here's a complete example showing a typical user journey from registration to transfer:

### Step 1: Register Alice
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "alice@example.com", "initial_balance": 1000.0}}'

# Save the token from response: "token": "alice_jwt_token"
```

### Step 2: Register Bob
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "bob@example.com"}}'

# Save the token from response: "token": "bob_jwt_token"
```

### Step 3: Alice Checks Balance
```bash
curl -X GET http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer alice_jwt_token"

# Response shows balance: 1000.0
```

### Step 4: Alice Deposits Money
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer alice_jwt_token" \
  -H "Content-Type: application/json" \
  -d '{"balance": {"operation": "deposit", "amount": 500.0, "description": "Bonus"}}'

# Alice's balance is now 1500.0
```

### Step 5: Alice Transfers to Bob
```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer alice_jwt_token" \
  -H "Content-Type: application/json" \
  -d '{"transfer": {"to_email": "bob@example.com", "amount": 250.0, "description": "Payment"}}'

# Alice's balance: 1250.0, Bob's balance: 250.0
```

### Step 6: Bob Checks Balance
```bash
curl -X GET http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer bob_jwt_token"

# Response shows balance: 250.0
```

### Step 7: Bob Withdraws Money
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer bob_jwt_token" \
  -H "Content-Type: application/json" \
  -d '{"balance": {"operation": "withdraw", "amount": 100.0, "description": "ATM"}}'

# Bob's balance is now 150.0
```

---

## 8. Error Handling Reference

### Authentication Errors
- **401 Unauthorized**: Missing, invalid, or expired JWT token
- **403 Forbidden**: Valid token but insufficient permissions (not used in current API)

### Validation Errors (422 Unprocessable Entity)
- Invalid email format
- Negative amounts
- Zero amounts for transactions
- Amounts exceeding maximum limit (1,000,000)
- Insufficient funds
- Non-existent recipient users
- Self-transfer attempts
- Invalid operation types

### Server Errors (500 Internal Server Error)
- Database connection issues
- Unexpected application errors
- Service unavailable

---

## 9. Testing the API

### Using curl for Testing
1. Save JWT tokens to environment variables for easier testing:
```bash
export ALICE_TOKEN="alice_jwt_token_here"
export BOB_TOKEN="bob_jwt_token_here"
```

2. Use variables in curl commands:
```bash
curl -X GET http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer $ALICE_TOKEN"
```

### Testing Authentication
Test authentication by making requests without tokens:
```bash
# Should return 401 Unauthorized
curl -X GET http://localhost:3000/api/v1/profile/balance
```

### Testing Edge Cases
Test various edge cases like:
- Maximum amounts
- Precision decimal amounts (e.g., 123.45)
- Empty descriptions
- Case-insensitive email lookups
- Whitespace in email addresses

---

## 10. Integration Notes

### Frontend Integration
- Store JWT tokens securely (not in localStorage for security)
- Implement token refresh logic for expired tokens
- Handle all error responses gracefully
- Show loading states during API calls

### Mobile App Integration
- Use secure storage for JWT tokens
- Implement offline transaction queuing
- Handle network timeouts gracefully
- Validate amounts on client side before sending

### Backend Integration
- Implement rate limiting for production
- Add request logging for audit trails
- Monitor API performance and errors
- Implement caching where appropriate

---

This documentation covers all available API endpoints with comprehensive examples. For additional support or questions, refer to the main [README.md](../README.md) file.
