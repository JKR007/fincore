# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:balance) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }

    it 'validates balance is numeric and non-negative' do
      invalid_user = build(:user, balance: -10.0)
      expect(invalid_user).not_to be_valid
      expect(invalid_user.errors[:balance]).to include('cannot be negative')
    end

    it 'allows zero balance' do
      valid_user = build(:user, balance: 0)
      expect(valid_user).to be_valid
    end

    it 'allows positive balance' do
      valid_user = build(:user, balance: 100.50)
      expect(valid_user).to be_valid
    end

    it { is_expected.to allow_value('user@example.com').for(:email) }
    it { is_expected.to allow_value('user.name+tag@example.co.uk').for(:email) }
    it { is_expected.not_to allow_value('invalid_email').for(:email) }
    it { is_expected.not_to allow_value('@example.com').for(:email) }
    it { is_expected.not_to allow_value('user@').for(:email) }

    it { is_expected.to have_db_index(:email).unique(true) }
  end

  describe 'attributes' do
    it { is_expected.to have_db_column(:email).of_type(:string).with_options(null: false) }

    it 'has correct balance column configuration' do
      expect(user).to have_db_column(:balance)
        .of_type(:decimal)
        .with_options(precision: 15, scale: 2, default: 0.0, null: false)
    end

    it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }
  end

  describe 'callbacks' do
    describe 'when email normalization occurs' do
      it 'converts email to lowercase' do
        test_user = build(:user, email: 'TEST@EXAMPLE.COM')
        test_user.valid?
        expect(test_user.email).to eq('test@example.com')
      end

      it 'strips whitespace from email' do
        test_user = build(:user, email: '  user@example.com  ')
        test_user.valid?
        expect(test_user.email).to eq('user@example.com')
      end

      it 'handles both case and whitespace' do
        test_user = build(:user, email: '  TEST@EXAMPLE.COM  ')
        test_user.valid?
        expect(test_user.email).to eq('test@example.com')
      end

      it 'normalizes email when creating user' do
        created_user = create(:user, email: 'TEST@EXAMPLE.COM')
        expect(created_user.reload.email).to eq('test@example.com')
      end
    end
  end

  describe 'instance methods' do
    let(:test_user) { create(:user, :with_balance) }

    it 'is valid with valid attributes' do
      expect(test_user).to be_valid
    end

    it 'has the correct balance format' do
      expect(test_user.balance).to be_a(BigDecimal)
      expect(test_user.balance.to_s).to eq('100.5')
    end
  end

  describe 'database constraints' do
    context 'when testing unique email constraint' do
      it 'is enforced at model level' do
        create(:user, email: 'test@example.com')
        duplicate_user = build(:user, email: 'test@example.com')

        expect(duplicate_user).not_to be_valid
        expect(duplicate_user.errors[:email]).to include('has already been taken')
      end

      it 'is enforced at database level' do
        create(:user, email: 'test@example.com')

        expect do
          duplicate_user = described_class.new(email: 'test@example.com', balance: 100)
          duplicate_user.save!(validate: false)
        end.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context 'when testing positive balance constraint' do
      it 'is enforced at model level' do
        invalid_user = build(:user, balance: -10.0)
        expect(invalid_user).not_to be_valid
        expect(invalid_user.errors[:balance]).to include('cannot be negative')
      end

      it 'is enforced at database level' do
        test_user = create(:user)

        expect do
          ActiveRecord::Base.connection.execute(
            "UPDATE users SET balance = -10.0 WHERE id = #{test_user.id}"
          )
        end.to raise_error(ActiveRecord::StatementInvalid, /positive_balance/)
      end
    end
  end
end
