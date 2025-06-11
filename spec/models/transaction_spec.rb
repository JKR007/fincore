# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transaction, type: :model do
  subject(:transaction) { build(:transaction) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:transaction_type) }
    it { is_expected.to validate_presence_of(:balance_before) }
    it { is_expected.to validate_presence_of(:balance_after) }

    it { is_expected.to validate_inclusion_of(:transaction_type).in_array(Transaction::TRANSACTION_TYPES) }

    it 'validates amount is not zero' do
      transaction.amount = 0
      expect(transaction).not_to be_valid
      expect(transaction.errors[:amount]).to include('cannot be zero')
    end

    it 'validates balance_before is non-negative' do
      transaction.balance_before = -10.0
      expect(transaction).not_to be_valid
      expect(transaction.errors[:balance_before]).to include('must be greater than or equal to 0')
    end

    it 'validates balance_after is non-negative' do
      transaction.balance_after = -5.0
      expect(transaction).not_to be_valid
      expect(transaction.errors[:balance_after]).to include('must be greater than or equal to 0')
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:transfer_in) { create(:transaction, :transfer_in, user: user) }

    describe '.recent' do
      it 'orders by created_at descending' do
        expect(described_class.recent.first).to eq(transfer_in)
      end
    end
  end

  describe 'instance methods' do
    describe '#deposit?' do
      it 'returns true for deposit transaction' do
        deposit_transaction = build(:transaction, :deposit)
        expect(deposit_transaction.deposit?).to be true
      end

      it 'returns false for non-deposit transaction' do
        withdrawal_transaction = build(:transaction, :withdrawal)
        expect(withdrawal_transaction.deposit?).to be false
      end
    end

    describe '#withdrawal?' do
      it 'returns true for withdrawal transaction' do
        withdrawal_transaction = build(:transaction, :withdrawal)
        expect(withdrawal_transaction.withdrawal?).to be true
      end
    end

    describe '#transfer?' do
      it 'returns true for transfer transactions' do
        transfer_transaction = build(:transaction, :transfer_in)
        expect(transfer_transaction.transfer?).to be true
      end
    end
  end
end
