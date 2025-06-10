# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransferService, type: :service do
  let(:from_user) { create(:user, email: 'sender@example.com', balance: 1000.0) }
  let(:to_user) { create(:user, email: 'recipient@example.com', balance: 200.0) }

  before do
    allow(User).to receive(:lock).and_call_original
    allow(User).to receive(:find).with(from_user.id).and_call_original
    allow(User).to receive(:find).with(to_user.id).and_call_original
  end

  describe '.transfer_by_email' do
    context 'with valid email' do
      it 'transfers money to user by email' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 150.0)

        expect(result[:success]).to be true
        expect(result[:transfer][:amount]).to eq(150.0)
        expect(result[:transfer][:to_user][:email]).to eq('recipient@example.com')

        from_user.reload
        to_user.reload
        expect(from_user.balance).to eq(850.0)
        expect(to_user.balance).to eq(350.0)
      end

      it 'transfers money between users and creates transaction records' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 300.0)

        expect(result[:success]).to be true
        expect(result[:transfer][:amount]).to eq(300.0)
        expect(result[:transfer][:from_user][:balance]).to eq(700.0)
        expect(result[:transfer][:to_user][:balance]).to eq(500.0)

        from_user.reload
        to_user.reload
        expect(from_user.balance).to eq(700.0)
        expect(to_user.balance).to eq(500.0)
        expect(from_user.transactions.count).to eq(1)
        expect(to_user.transactions.count).to eq(1)
      end

      it 'creates correct transaction records for both users' do
        described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 250.0)

        from_transaction = from_user.transactions.last
        to_transaction = to_user.transactions.last

        expect(from_transaction.amount).to eq(-250.0)
        expect(from_transaction.transaction_type).to eq('transfer_out')
        expect(from_transaction.balance_before).to eq(1000.0)
        expect(from_transaction.balance_after).to eq(750.0)
        expect(from_transaction.description).to eq("Transfer to #{'recipient@example.com'}")

        expect(to_transaction.amount).to eq(250.0)
        expect(to_transaction.transaction_type).to eq('transfer_in')
        expect(to_transaction.balance_before).to eq(200.0)
        expect(to_transaction.balance_after).to eq(450.0)
        expect(to_transaction.description).to eq("Transfer from #{from_user.email}")
      end

      it 'uses custom description when provided' do
        described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 100.0, description: 'Payment for services')

        from_transaction = from_user.transactions.last
        to_transaction = to_user.transactions.last

        expect(from_transaction.description).to eq('Payment for services')
        expect(to_transaction.description).to eq('Payment for services')
      end

      it 'handles decimal amounts correctly' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: '123.45')

        expect(result[:success]).to be true
        from_user.reload
        to_user.reload
        expect(from_user.balance).to eq(876.55)
        expect(to_user.balance).to eq(323.45)
      end

      it 'allows transfer of entire balance' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 1000.0)

        expect(result[:success]).to be true
        from_user.reload
        expect(from_user.balance).to eq(0.0)
      end

      it 'returns proper response structure' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 100.0)

        expect(result.keys).to contain_exactly(:success, :transfer, :transactions)
        expect(result[:transfer].keys).to contain_exactly(:amount, :from_user, :to_user, :description)
        expect(result[:transactions]).to be_an(Array)
        expect(result[:transactions].size).to eq(2)
      end

      it 'handles case insensitive email lookup' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com'.upcase, amount: 100.0)

        expect(result[:success]).to be true
        expect(result[:transfer][:to_user][:email]).to eq('recipient@example.com')
      end

      it 'handles email with whitespace' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: "  #{'recipient@example.com'}  ", amount: 100.0)

        expect(result[:success]).to be true
        expect(result[:transfer][:to_user][:email]).to eq('recipient@example.com')
      end
    end

    context 'with invalid parameters' do
      it 'returns error for insufficient funds' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 1500.0)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Insufficient funds for transfer')

        from_user.reload
        to_user.reload
        expect(from_user.balance).to eq(1000.0)
        expect(to_user.balance).to eq(200.0)
        expect(from_user.transactions.count).to eq(0)
        expect(to_user.transactions.count).to eq(0)
      end

      it 'returns error for negative amount' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: -50.0)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Transfer amount must be positive')
      end

      it 'returns error for zero amount' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 0)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Transfer amount must be positive')
      end

      it 'returns error for nil amount' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: nil)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Transfer amount must be positive')
      end

      it 'returns error for amount too large' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 2_000_000)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Transfer amount too large')
      end

      it 'returns error for same user transfer by email' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: from_user.email, amount: 100.0)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Cannot transfer to the same user')
      end

      it 'returns error for exact insufficient funds scenario' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 1000.01)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Insufficient funds for transfer')
      end

      it 'raises unexpected errors instead of catching them' do
        allow(described_class).to receive(:create_transfer_in_transaction!).and_raise(
          StandardError.new('Transaction creation failed')
        )

        expect {
          described_class.transfer_by_email(
            from_user: from_user,
            to_email: 'recipient@example.com',
            amount: 100.0
          )
        }.to raise_error(StandardError, 'Transaction creation failed')
      end
    end

    context 'with invalid email' do
      it 'returns error for non-existent email' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: 'nonexistent@example.com', amount: 100.0)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Recipient user not found')

        from_user.reload
        expect(from_user.balance).to eq(1000.0)
        expect(from_user.transactions.count).to eq(0)
      end

      it 'returns error for blank email' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: '', amount: 100.0)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Recipient user not found')
      end

      it 'returns error for nil email' do
        result = described_class.transfer_by_email(from_user: from_user, to_email: nil, amount: 100.0)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('Recipient user not found')
      end
    end
  end

  describe 'integration scenarios' do
    it 'handles multiple transfers correctly' do
      result1 = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 200.0)
      expect(result1[:success]).to be true

      from_user.reload
      to_user.reload
      expect(from_user.balance).to eq(800.0)
      expect(to_user.balance).to eq(400.0)

      result2 = described_class.transfer_by_email(from_user: to_user, to_email: from_user.email, amount: 100.0)
      expect(result2[:success]).to be true

      from_user.reload
      to_user.reload
      expect(from_user.balance).to eq(900.0)
      expect(to_user.balance).to eq(300.0)

      expect(from_user.transactions.count).to eq(2)
      expect(to_user.transactions.count).to eq(2)
    end

    it 'maintains audit trail across transfers' do
      described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 300.0)

      from_transactions = from_user.transactions.recent
      to_transactions = to_user.transactions.recent

      expect(from_transactions.first.transaction_type).to eq('transfer_out')
      expect(from_transactions.first.balance_before).to eq(1000.0)
      expect(from_transactions.first.balance_after).to eq(700.0)

      expect(to_transactions.first.transaction_type).to eq('transfer_in')
      expect(to_transactions.first.balance_before).to eq(200.0)
      expect(to_transactions.first.balance_after).to eq(500.0)
    end

    it 'handles transfer with existing balance operations' do
      BalanceOperationService.process_balance_operation(user: from_user, operation: 'deposit', amount: 500.0)
      from_user.reload
      expect(from_user.balance).to eq(1500.0)

      result = described_class.transfer_by_email(from_user: from_user, to_email: 'recipient@example.com', amount: 600.0)
      expect(result[:success]).to be true

      from_user.reload
      to_user.reload
      expect(from_user.balance).to eq(900.0)
      expect(to_user.balance).to eq(800.0)
      expect(from_user.transactions.count).to eq(2)
    end
  end
end
