# Fincore - API

A robust and secure financial API built with Ruby on Rails that provides user account management, balance operations, and money transfers with comprehensive audit trails.

## Features

- **User Management**: Email-based user registration and authentication (passwordless)
- **JWT Authentication**: Secure token-based authentication system with 24-hour expiration
- **Balance Operations**: Deposit and withdraw money with transaction history
- **Money Transfers**: Transfer funds between users via email with atomic transactions
- **Transaction Audit**: Complete audit trail for all financial operations
- **API-Only**: Clean REST API with JSON responses
- **Thread Safety**: Database locking for concurrent transaction safety
- **Comprehensive Testing**: Full test coverage with RSpec (95%+ coverage goal)
- **Error Handling**: Robust error handling with meaningful messages

## Technology Stack

- **Ruby**: 3.4.4
- **Rails**: 8.0.2 (API-only mode)
- **Database**: PostgreSQL with precision decimal handling
- **Authentication**: JWT (JSON Web Tokens)
- **Testing**: RSpec, FactoryBot, Faker
- **Code Quality**: RuboCop, SimpleCov
- **Security**: bundler-audit, brakeman (static analysis)
- **Gems**: jwt, pg, rspec-rails, factory_bot_rails, shoulda-matchers

## Prerequisites

Before setting up the project, ensure you have the following installed:

- **Ruby 3.4.4** (managed with RVM or rbenv)
- **Rails 8.0.2**
- **PostgreSQL** (version 12 or higher)
- **Git**
- **Bundler** gem

### Installing Prerequisites

#### 1. Install RVM and Ruby
```bash
# Install RVM
curl -sSL https://get.rvm.io | bash -s stable

# Install Ruby 3.4.4
rvm install 3.4.4
# OR
rvm install "ruby-3.4.4" --with-openssl-dir="$(brew --prefix)/opt/openssl@1.1/"

rvm use 3.4.4 --default
```

#### 2. Install Rails
```bash
gem install rails -v 8.0.2
```

#### 3. Install PostgreSQL
```bash
# macOS (using Homebrew)
brew install postgresql
brew services start postgresql

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib

# Create PostgreSQL user (optional)
createuser -d postgres
```

## Project Setup

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/fincore.git
cd fincore
```

### 2. Install Dependencies
```bash
# RVM will automatically switch to Ruby 3.4.4 due to .ruby-version file
bundle install
```

### 3. Database Setup
```bash
# Create database users
createuser -s fincore_dev fincore_test

# Create databases
rails db:create

# Run migrations
rails db:migrate

# Verify setup
rails db:migrate:status
```

### 4. Run Tests (Recommended)
```bash
# Run the full test suite
bundle exec rspec

# Run with coverage report
bundle exec rspec --format documentation

# Check code quality
bundle exec rubocop

# Auto-fix rubocop issues
bundle exec rubocop -A

# Security vulnerability scanning
bundle exec bundler-audit check --update

# Static security analysis
bundle exec brakeman -q
```

### 6. Start the Server
```bash
# Start Rails server
rails server

# Server will be available at http://localhost:3000
```

## API Overview

### Base URL
```
http://localhost:3000/api/v1
```

### Authentication
Most endpoints require a JWT token in the Authorization header:
```
Authorization: Bearer <your_jwt_token>
```

### Available Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/auth/register` | Register a new user | No |
| POST | `/auth/login` | Login existing user | No |
| GET | `/profile/balance` | Get current user balance | Yes |
| PATCH | `/profile/balance` | Deposit/Withdraw money | Yes |
| POST | `/transfers` | Transfer money between users | Yes |

For detailed API examples with curl commands, see [API Documentation](docs/api_examples.md).

## Quick Start Guide

### 1. Register a User
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "alice@example.com", "initial_balance": 1000.0}}'
```

### 2. Login and Get Token
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "alice@example.com"}}'
```

### 3. Check Balance
```bash
curl -X GET http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 4. Deposit Money
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"balance": {"operation": "deposit", "amount": 250.0, "description": "Salary"}}'
```

### 5. Withdraw Money
```bash
curl -X PATCH http://localhost:3000/api/v1/profile/balance \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"balance": {"operation": "withdraw", "amount": 50.0, "description": "ATM withdrawal"}}'
```

### 6. Transfer Money
```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"transfer": {"to_email": "bob@example.com", "amount": 100.0, "description": "Payment"}}'
```

## Project Structure

```
fincore/
├── app/
│   ├── controllers/
│   │   └── api/
│   │       ├── base_controller.rb         # Base API controller with auth
│   │       └── v1/                        # Versioned API controllers
│   │           ├── base_controller.rb     # V1 base controller
│   │           ├── authentication_controller.rb
│   │           ├── users_controller.rb    # Balance operations
│   │           └── transfers_controller.rb
│   ├── models/
│   │   ├── application_record.rb          # Base model
│   │   ├── user.rb                        # User model with validations
│   │   └── transaction.rb                 # Transaction audit model
│   └── services/                          # Business logic layer
│       ├── authentication_service.rb      # User registration & login
│       ├── balance_operation_service.rb   # Deposit & withdrawal logic
│       ├── transfer_service.rb            # Money transfer logic
│       └── json_web_token.rb              # JWT token management
├── config/
│   ├── routes.rb                          # API routing configuration
│   ├── database.yml                       # Database configuration
│   └── application.rb                     # Rails configuration
├── db/
│   ├── migrate/                           # Database migrations
│   │   ├── 001_create_users.rb
│   │   └── 002_create_transactions.rb
│   └── schema.rb                          # Current database schema
├── spec/                                  # Test suite
│   ├── controllers/                       # Controller tests
│   ├── models/                           # Model tests
│   ├── services/                         # Service tests
│   ├── factories/                        # Test data factories
│   ├── support/
│   │   └── authentication_helpers.rb     # Test helpers
│   ├── rails_helper.rb                   # RSpec configuration
│   └── spec_helper.rb
├── docs/
│   └── api_documentation.md                   # Complete API documentation
├── Gemfile                               # Gem dependencies
├── .ruby-version                         # Ruby version specification
├── .rspec                               # RSpec configuration
└── README.md                            # This file
```

## User Flow

### 1. User Registration
- User provides email and optional initial balance
- System creates account with normalized email (lowercase, trimmed)
- Returns JWT token for immediate authentication
- User starts with zero balance if not specified
- Email must be unique across the system

### 2. Authentication
- User logs in with email only (passwordless system)
- System validates user exists and returns JWT token
- Token expires after 24 hours
- Token required for all subsequent operations

### 3. Balance Operations
- **Check Balance**: View current account balance and user info
- **Deposit**: Add money to account with optional description
- **Withdraw**: Remove money from account (insufficient funds prevented)
- All operations create detailed audit trail entries
- Operations are atomic and thread-safe

### 4. Money Transfers
- **Transfer by Email**: Send money using recipient's email address
- System validates recipient exists and sender has sufficient funds
- Creates transaction records for both sender and recipient
- Atomic operations ensure data consistency
- Supports custom descriptions for transfers

### 5. Transaction History
- Every operation creates a transaction record
- Tracks balance before and after each operation
- Includes timestamps, descriptions, and transaction types
- Provides complete audit trail for compliance

## Data Models

### User Model
```ruby
# Table: users
id              # Primary key (bigint)
email           # Unique email address (string, indexed)
balance         # Current balance (decimal 15,2, default: 0.0)
created_at      # Timestamp
updated_at      # Timestamp

# Constraints:
# - email uniqueness (case-insensitive)
# - balance >= 0 (database constraint)
# - email format validation
```

### Transaction Model
```ruby
# Table: transactions
id                # Primary key (bigint)
user_id           # Foreign key to users (bigint, indexed)
amount            # Transaction amount (decimal 15,2)
transaction_type  # Type: deposit, withdrawal, transfer_in, transfer_out
description       # Optional description (string)
balance_before    # Balance before transaction (decimal 15,2)
balance_after     # Balance after transaction (decimal 15,2)
created_at        # Timestamp (indexed)
updated_at        # Timestamp

# Constraints:
# - amount cannot be zero
# - balance_before >= 0
# - balance_after >= 0
# - transaction_type in allowed values
```

## Security Features

- **JWT Authentication**: Secure token-based authentication with expiration
- **Input Validation**: Comprehensive validation on all inputs
- **SQL Injection Protection**: Parameterized queries via ActiveRecord
- **Email Normalization**: Consistent email formatting (lowercase, trimmed)
- **Balance Constraints**: Database-level constraints prevent negative balances
- **Atomic Transactions**: Database transactions ensure data consistency
- **Error Handling**: Secure error messages without sensitive information exposure
- **Thread Safety**: Database locking prevents race conditions in transfers
- **Amount Limits**: Maximum transaction amount of 1,000,000 to prevent abuse

## API Response Format

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

### HTTP Status Codes
- `200`: Success (GET, PATCH requests)
- `201`: Created (POST requests)
- `401`: Unauthorized (missing/invalid token)
- `404`: Not Found (resource doesn't exist)
- `422`: Unprocessable Entity (validation errors)
- `500`: Internal Server Error

## API Versioning

The API is versioned using URL path versioning:
- Current version: `v1`
- All endpoints prefixed with `/api/v1/`
- Future versions can be added without breaking existing clients

## Continuous Integration

The project uses GitHub Actions for automated testing and quality assurance. The CI pipeline runs on all pull requests and pushes to `main`.

### CI Pipeline Jobs

#### 1. Security Analysis
- **Brakeman**: Static security analysis for Rails vulnerabilities
- **Bundler Audit**: Scans for vulnerable gem dependencies
- **Runtime**: ~20-30 seconds

#### 2. Test Suite
- **Database**: PostgreSQL 16 service container
- **RSpec**: Full test suite execution with progress reporting
- **Coverage**: SimpleCov report generation and artifact upload
- **Database Setup**: Automated schema creation and migrations
- **Runtime**: ~50-60 seconds

#### 3. Code Quality (Lint)
- **RuboCop**: Code style and convention enforcement
- **Multiple Formats**: GitHub annotations + detailed output on failure
- **Runtime**: ~15-20 seconds

#### 4. Quality Gate
- **Summary**: Consolidates results from all jobs
- **Pass Criteria**: All security, test, and lint checks must pass
- **GitHub Summary**: Provides clear ✅ / ❌ status overview

### Local CI Simulation

Run the same checks locally before pushing:

```bash
# Security checks (matches CI security job)
bin/brakeman --no-pager
bundle exec bundler-audit --update

# Tests (matches CI test job)  
bundle exec rspec --format progress

# Code quality (matches CI lint job)
bin/rubocop -f github
bundle exec rubocop --format simple
```

### CI Configuration

The CI pipeline is defined in `.github/workflows/ci.yml` and includes:

- **Ruby Version**: 3.4.4 (in CI environment)
- **PostgreSQL**: Version 16 with health checks
- **Parallel Execution**: Security, test, and lint jobs run concurrently
- **Artifact Storage**: Test coverage reports uploaded for review
- **Branch Triggers**: Runs on `main` and `develop` branches

### Coverage Reports

Test coverage artifacts are automatically uploaded and can be downloaded from the GitHub Actions run page. The pipeline checks for coverage file generation and provides status updates.

### Quality Standards

All pull requests must pass:
- **Security**: No vulnerabilities detected
- **Tests**: test coverage, all specs passing  
- **Lint**: RuboCop style compliance
- **Quality Gate**: Combined status check

---

## Testing

### Running Tests
```bash
# Run all tests
bundle exec rspec

# Run specific test files
bundle exec rspec spec/models/user_spec.rb
bundle exec rspec spec/services/authentication_service_spec.rb
bundle exec rspec spec/controllers/api/v1/users_controller_spec.rb

# Run with documentation format
bundle exec rspec --format documentation

# Run tests with coverage
COVERAGE=true bundle exec rspec
```

### Test Coverage
```bash
# Generate and view coverage report
bundle exec rspec
open coverage/index.html
```

## Development Guidelines

### Code Style
```bash
# Check code style
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -A
```

### Commit Messages
Follow conventional commit format:
```
feat: add money transfer functionality
fix: resolve balance calculation precision issue
docs: update API documentation
test: add transfer service integration tests
```

### Pull Request Process
1. Create feature branch from main
2. Write tests for new functionality
3. Ensure all tests pass
4. Run rubocop and fix any issues
5. Update documentation if needed
6. Submit pull request with clear description

## Support

For questions or issues:
1. Check the [API Documentation](./docs/api_documentation.md)
2. Review test files for usage examples

## Acknowledgments

- Built with Ruby on Rails framework
- JWT authentication implementation
- Comprehensive testing with RSpec
- Code quality maintained with RuboCop
- PostgreSQL for reliable data storage

### Health Check
```bash
# Application health endpoint
curl http://localhost:3000/up
```

**Fincore** - A professional financial API solution for modern applications.
