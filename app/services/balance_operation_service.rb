# frozen_string_literal: true

class BalanceOperationService
  class InsufficientFundsError < StandardError; end
  class InvalidAmountError < StandardError; end

  class << self
    def process_balance_operation(user:, operation:, amount:, description: nil)
      return error_response([ "User not found" ]) unless user

      case operation
      when "deposit"
        deposit(user: user, amount: amount, description: description)
      when "withdraw"
        withdraw(user: user, amount: amount, description: description)
      else
        error_response([ "Invalid operation. Use deposit or withdraw" ])
      end
    end

    def get_balance(user:)
      {
        success: true,
        balance: user.balance,
        user: { email: user.email, balance: user.balance }
      }
    end

    private

    def deposit(user:, amount:, description: nil)
      validate_amount!(amount, :deposit)
      process_deposit(user, amount, description)
    rescue InvalidAmountError => e
      error_response([ e.message ])
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.record.errors.full_messages)
    end

    def withdraw(user:, amount:, description: nil)
      validate_amount!(amount, :withdrawal)
      process_withdrawal(user, amount, description)
    rescue InvalidAmountError, InsufficientFundsError => e
      error_response([ e.message ])
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.record.errors.full_messages)
    end

    def process_deposit(user, amount, description)
      ActiveRecord::Base.transaction do
        user_locked = User.lock.find(user.id)
        balance_before = user_locked.balance
        new_balance = balance_before + amount.to_d

        user_locked.update!(balance: new_balance)

        transaction = create_deposit_transaction!(
          user_locked, amount, description, balance_before, new_balance
        )

        success_response(user_locked, transaction)
      end
    end

    def process_withdrawal(user, amount, description)
      ActiveRecord::Base.transaction do
        user_locked = User.lock.find(user.id)
        balance_before = user_locked.balance
        new_balance = balance_before - amount.to_d

        raise InsufficientFundsError, "Insufficient funds" if new_balance.negative?

        user_locked.update!(balance: new_balance)

        transaction = create_withdrawal_transaction!(
          user_locked, amount, description, balance_before, new_balance
        )

        success_response(user_locked, transaction)
      end
    end

    def create_deposit_transaction!(user, amount, description, balance_before, balance_after)
      create_transaction!(
        user: user,
        amount: amount,
        transaction_type: "deposit",
        description: description || "Deposit of #{amount}",
        balance_before: balance_before,
        balance_after: balance_after
      )
    end

    def create_withdrawal_transaction!(user, amount, description, balance_before, balance_after)
      create_transaction!(
        user: user,
        amount: -amount.to_d,
        transaction_type: "withdrawal",
        description: description || "Withdrawal of #{amount}",
        balance_before: balance_before,
        balance_after: balance_after
      )
    end

    def validate_amount!(amount, operation_type)
      raise_invalid_amount!(operation_type) if invalid_amount?(amount)
      raise_amount_too_large!(operation_type) if amount.to_d > 1_000_000
    end

    def invalid_amount?(amount)
      amount.nil? || amount.to_d <= 0
    end

    def raise_invalid_amount!(operation_type)
      raise InvalidAmountError, "#{operation_type.to_s.capitalize} amount must be positive"
    end

    def raise_amount_too_large!(operation_type)
      raise InvalidAmountError, "#{operation_type.to_s.capitalize} amount too large"
    end

    def create_transaction!(user:, amount:, transaction_type:, description:, balance_before:, balance_after:)
      user.transactions.create!(
        amount: amount,
        transaction_type: transaction_type,
        description: description,
        balance_before: balance_before,
        balance_after: balance_after
      )
    end

    def success_response(user, transaction)
      {
        success: true,
        user: user_response_data(user),
        transaction: transaction_response_data(transaction)
      }
    end

    def user_response_data(user)
      { email: user.email, balance: user.balance }
    end

    def transaction_response_data(transaction)
      {
        id: transaction.id,
        amount: transaction.amount,
        type: transaction.transaction_type,
        description: transaction.description,
        balance_before: transaction.balance_before.to_f,
        balance_after: transaction.balance_after.to_f,
        created_at: transaction.created_at
      }
    end

    def error_response(errors)
      { success: false, errors: Array(errors) }
    end
  end
end
