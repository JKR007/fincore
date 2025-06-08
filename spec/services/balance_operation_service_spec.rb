# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BalanceOperationService, type: :service do
  let(:user) { create(:user, balance: 500.0) }

  describe ".process_balance_operation" do
    context 'when operation deposit' do
      context 'with valid parameters' do
        it 'increases user balance and creates transaction record' do
          result = described_class.process_balance_operation(user: user, operation: 'deposit', amount: 100.50)

          expect(result[:success]).to be true
          expect(result[:user][:balance]).to eq(600.50)
          expect(result[:transaction][:amount]).to eq(100.50)
          expect(result[:transaction][:type]).to eq('deposit')

          user.reload
          expect(user.balance).to eq(600.50)
          expect(user.transactions.count).to eq(1)
        end

        it 'creates transaction with correct audit trail' do
          described_class.process_balance_operation(user: user, operation: 'deposit', amount: 250.75)
          transaction = Transaction.last

          expect(transaction.user).to eq(user)
          expect(transaction.amount).to eq(250.75)
          expect(transaction.transaction_type).to eq('deposit')
          expect(transaction.balance_before).to eq(500.0)
          expect(transaction.balance_after).to eq(750.75)
          expect(transaction.description).to eq('Deposit of 250.75')
        end

        it 'uses custom description when provided' do
          described_class.process_balance_operation(
            user: user,
            operation: 'deposit',
            amount: 75.0,
            description: 'Salary payment'
          )

          transaction = Transaction.last
          expect(transaction.description).to eq('Salary payment')
        end

        it 'handles decimal amounts correctly' do
          result = described_class.process_balance_operation(user: user, operation: 'deposit', amount: '123.456')

          expect(result[:success]).to be true
          user.reload
          expect(user.balance).to eq(623.46)
        end

        it 'returns proper response structure' do
          result = described_class.process_balance_operation(user: user, operation: 'deposit', amount: 100.0)

          expect(result.keys).to contain_exactly(:success, :user, :transaction)
          expect(result[:user].keys).to contain_exactly(:email, :balance)
          expect(result[:transaction].keys).to contain_exactly(
            :id, :amount, :type, :description, :balance_before, :balance_after, :created_at
          )
        end
      end

      context 'with invalid parameters' do
        it 'returns error for negative amount' do
          result = described_class.process_balance_operation(user: user, operation: 'deposit', amount: -50.0)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Deposit amount must be positive')

          user.reload
          expect(user.balance).to eq(500.0)
          expect(user.transactions.count).to eq(0)
        end

        it 'returns error for zero amount' do
          result = described_class.process_balance_operation(user: user, operation: 'deposit', amount: 0)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Deposit amount must be positive')
        end

        it 'returns error for nil amount' do
          result = described_class.process_balance_operation(user: user, operation: 'deposit', amount: nil)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Deposit amount must be positive')
        end

        it 'returns error for amount too large' do
          result = described_class.process_balance_operation(user: user, operation: 'deposit', amount: 2_000_000)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Deposit amount too large')
        end

        it 'handles database transaction failures' do
          allow(user).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(user))

          user.errors.add(:balance, 'Database constraint violation')

          result = described_class.process_balance_operation(user: user, operation: 'deposit', amount: 100.0)

          expect(result[:success]).to be false
          expect(result[:errors]).to be_present
        end

        it 'raises unexpected errors instead of catching them' do
          allow(described_class).to receive(:create_deposit_transaction!).and_raise(StandardError.new('Database connection lost'))

          expect { described_class.process_balance_operation(user: user, operation: 'deposit', amount: 100.0) }.to raise_error(StandardError, 'Database connection lost')
        end
      end
    end

    context 'when operation withdraw' do
      context 'with valid parameters' do
        it 'decreases user balance and creates transaction record' do
          result = described_class.process_balance_operation(user: user, operation: 'withdraw', amount: 150.25)

          expect(result[:success]).to be true
          expect(result[:user][:balance]).to eq(349.75)
          expect(result[:transaction][:amount]).to eq(-150.25)
          expect(result[:transaction][:type]).to eq('withdrawal')

          user.reload
          expect(user.balance).to eq(349.75)
          expect(user.transactions.count).to eq(1)
        end

        it 'creates transaction with correct audit trail' do
          described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 200.0)
          transaction = Transaction.last

          expect(transaction.user).to eq(user)
          expect(transaction.amount).to eq(-200.0)
          expect(transaction.transaction_type).to eq('withdrawal')
          expect(transaction.balance_before).to eq(500.0)
          expect(transaction.balance_after).to eq(300.0)
          expect(transaction.description).to eq('Withdrawal of 200.0')
        end

        it 'uses custom description when provided' do
          described_class.process_balance_operation(
            user: user,
            operation: 'withdraw',
            amount: 100.0,
            description: 'ATM withdrawal'
          )

          transaction = Transaction.last
          expect(transaction.description).to eq('ATM withdrawal')
        end

        it 'allows withdrawal of entire balance' do
          result = described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 500.0)

          expect(result[:success]).to be true
          user.reload
          expect(user.balance).to eq(0.0)
        end
      end

      context 'with invalid parameters' do
        it 'returns error for insufficient funds' do
          result = described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 600.0)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Insufficient funds')

          user.reload
          expect(user.balance).to eq(500.0)
          expect(user.transactions.count).to eq(0)
        end

        it 'returns error for negative amount' do
          result = described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: -50.0)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Withdrawal amount must be positive')
        end

        it 'returns error for zero amount' do
          result = described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 0)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Withdrawal amount must be positive')
        end

        it 'returns error for nil amount' do
          result = described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: nil)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Withdrawal amount must be positive')
        end

        it 'returns error for amount too large' do
          result = described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 2_000_000)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Withdrawal amount too large')
        end

        it 'returns error for exact insufficient funds scenario' do
          result = described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 500.01)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Insufficient funds')
        end

        it 'raises unexpected errors instead of catching them' do
          allow(described_class).to receive(:create_withdrawal_transaction!).and_raise(StandardError.new('Transaction creation failed'))

          expect { described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 100.0) }.to raise_error(StandardError, 'Transaction creation failed')
        end
      end

      context 'with edge cases' do
        let(:zero_balance_user) { create(:user, balance: 0.0) }

        it 'prevents withdrawal from zero balance' do
          result = described_class.process_balance_operation(user: zero_balance_user, operation: 'withdraw', amount: 0.01)

          expect(result[:success]).to be false
          expect(result[:errors]).to include('Insufficient funds')
        end
      end
    end
  end

  describe '.get_balance' do
    it 'returns user balance information' do
      result = described_class.get_balance(user: user)

      expect(result[:success]).to be true
      expect(result[:balance]).to eq(500.0)
      expect(result[:user][:email]).to eq(user.email)
      expect(result[:user][:balance]).to eq(500.0)
    end

    it 'returns correct structure' do
      result = described_class.get_balance(user: user)

      expect(result.keys).to contain_exactly(:success, :balance, :user)
      expect(result[:user].keys).to contain_exactly(:email, :balance)
    end

    it 'raises unexpected errors instead of catching them' do
      allow(user).to receive(:balance).and_raise(StandardError.new('Database error'))

      expect { described_class.get_balance(user: user) }.to raise_error(StandardError, 'Database error')
    end
  end

  describe 'private methods' do
    describe '.validate_amount!' do
      it 'raises error for negative amount' do
        expect do
          described_class.send(:validate_amount!, -10.0, :deposit)
        end.to raise_error(BalanceOperationService::InvalidAmountError, 'Deposit amount must be positive')
      end

      it 'raises error for zero amount' do
        expect do
          described_class.send(:validate_amount!, 0, :withdrawal)
        end.to raise_error(BalanceOperationService::InvalidAmountError, 'Withdrawal amount must be positive')
      end

      it 'raises error for nil amount' do
        expect do
          described_class.send(:validate_amount!, nil, :deposit)
        end.to raise_error(BalanceOperationService::InvalidAmountError, 'Deposit amount must be positive')
      end

      it 'raises error for amount too large' do
        expect do
          described_class.send(:validate_amount!, 2_000_000, :deposit)
        end.to raise_error(BalanceOperationService::InvalidAmountError, 'Deposit amount too large')
      end

      it 'passes validation for valid amounts' do
        expect do
          described_class.send(:validate_amount!, 100.50, :deposit)
        end.not_to raise_error
      end
    end

    describe '.create_transaction!' do
      it 'creates transaction with correct user and amount' do
        transaction = described_class.send(
          :create_transaction!,
          user: user,
          amount: 100.0,
          transaction_type: 'deposit',
          description: 'Test transaction',
          balance_before: 500.0,
          balance_after: 600.0
        )

        expect(transaction).to be_persisted
        expect(transaction.user).to eq(user)
        expect(transaction.amount).to eq(100.0)
      end

      it 'creates transaction with correct type and balances' do
        transaction = described_class.send(
          :create_transaction!,
          user: user,
          amount: 100.0,
          transaction_type: 'deposit',
          description: 'Test transaction',
          balance_before: 500.0,
          balance_after: 600.0
        )

        expect(transaction.transaction_type).to eq('deposit')
        expect(transaction.balance_before).to eq(500.0)
        expect(transaction.balance_after).to eq(600.0)
      end
    end
  end

  describe 'integration scenarios' do
    it 'handles multiple operations correctly' do
      deposit_result = described_class.process_balance_operation(user: user, operation: 'deposit', amount: 200.0)
      expect(deposit_result[:success]).to be true

      user.reload
      expect(user.balance).to eq(700.0)

      withdraw_result = described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 150.0)
      expect(withdraw_result[:success]).to be true

      user.reload
      expect(user.balance).to eq(550.0)
      expect(user.transactions.count).to eq(2)
    end

    it 'maintains audit trail across operations' do
      described_class.process_balance_operation(user: user, operation: 'deposit', amount: 100.0)
      described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 50.0)

      transactions = user.transactions.recent

      expect(transactions.first.transaction_type).to eq('withdrawal')
      expect(transactions.first.balance_before).to eq(600.0)
      expect(transactions.first.balance_after).to eq(550.0)

      expect(transactions.last.transaction_type).to eq('deposit')
      expect(transactions.last.balance_before).to eq(500.0)
      expect(transactions.last.balance_after).to eq(600.0)
    end

    it 'handles concurrent operations safely' do
      user.balance

      result1 = described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 300.0)
      result2 = described_class.process_balance_operation(user: user, operation: 'withdraw',  amount: 300.0)

      expect(result1[:success]).to be true
      expect(result2[:success]).to be false
      expect(result2[:errors]).to include('Insufficient funds')
    end
  end
end
