# frozen_string_literal: true

class TransferService
  class InsufficientFundsError < StandardError; end
  class InvalidAmountError < StandardError; end
  class SameUserError < StandardError; end
  class UserNotFoundError < StandardError; end

  class << self
    def transfer_by_email(from_user:, to_email:, amount:, description: nil)
      to_user = User.find_by(email: to_email&.downcase&.strip)
      return error_response("Recipient user not found") unless to_user

      transfer(from_user: from_user, to_user: to_user, amount: amount, description: description)
    end

    private

    def transfer(from_user:, to_user:, amount:, description: nil)
      validate_transfer!(from_user, to_user, amount)
      process_transfer(from_user, to_user, amount, description)
    rescue InvalidAmountError, InsufficientFundsError, SameUserError, UserNotFoundError => e
      error_response([ e.message ])
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.record.errors.full_messages)
    end

    def process_transfer(from_user, to_user, amount, description)
      ActiveRecord::Base.transaction do
        from_user_locked = User.lock.find(from_user.id)
        to_user_locked   = User.lock.find(to_user.id)

        from_balance_before = from_user_locked.balance
        to_balance_before = to_user_locked.balance

        new_from_balance = from_balance_before - amount.to_d
        new_to_balance = to_balance_before + amount.to_d

        from_user_locked.update!(balance: new_from_balance)
        to_user_locked.update!(balance: new_to_balance)

        from_transaction = create_transfer_out_transaction!(
          from_user_locked, amount, description, from_balance_before, new_from_balance, to_user_locked
        )

        to_transaction = create_transfer_in_transaction!(
          to_user_locked, amount, description, to_balance_before, new_to_balance, from_user_locked
        )

        success_response(from_user_locked, to_user_locked, from_transaction, to_transaction)
      end
    end

    def validate_transfer!(from_user, to_user, amount)
      raise UserNotFoundError, "From user not found" unless from_user
      raise UserNotFoundError, "To user not found" unless to_user
      raise SameUserError, "Cannot transfer to the same user" if from_user.id == to_user.id

      validate_amount!(amount)
      validate_sufficient_funds!(from_user, amount)
    end

    def validate_amount!(amount)
      raise InvalidAmountError, "Transfer amount must be positive" if amount.nil? || amount.to_d <= 0

      return unless amount.to_d > 1_000_000

      raise InvalidAmountError, "Transfer amount too large"
    end

    def validate_sufficient_funds!(from_user, amount)
      return unless from_user.balance < amount.to_d

      raise InsufficientFundsError, "Insufficient funds for transfer"
    end

    def create_transfer_out_transaction!(user, amount, description, balance_before, balance_after, recipient)
      default_description = description || "Transfer to #{recipient.email}"

      user.transactions.create!(
        amount: -amount.to_d,
        transaction_type: "transfer_out",
        description: default_description,
        balance_before: balance_before,
        balance_after: balance_after
      )
    end

    def create_transfer_in_transaction!(user, amount, description, balance_before, balance_after, sender)
      default_description = description || "Transfer from #{sender.email}"

      user.transactions.create!(
        amount: amount.to_d,
        transaction_type: "transfer_in",
        description: default_description,
        balance_before: balance_before,
        balance_after: balance_after
      )
    end

    def success_response(from_user, to_user, from_transaction, to_transaction)
      {
        success: true,
        transfer: {
          amount: from_transaction.amount.abs,
          from_user: user_response_data(from_user),
          to_user: user_response_data(to_user),
          description: from_transaction.description
        },
        transactions: [
          transaction_response_data(from_transaction),
          transaction_response_data(to_transaction)
        ]
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
