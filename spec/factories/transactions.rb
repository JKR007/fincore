# frozen_string_literal: true

FactoryBot.define do
  factory :transaction do
    association :user
    amount { 100.50 }
    transaction_type { 'deposit' }
    description { 'Test transaction' }
    balance_before { 0.0 }
    balance_after { 100.50 }

    trait :deposit do
      transaction_type { 'deposit' }
      amount { 100.50 }
    end

    trait :withdrawal do
      transaction_type { 'withdrawal' }
      amount { -50.25 }
      balance_before { 100.50 }
      balance_after { 50.25 }
    end

    trait :transfer_in do
      transaction_type { 'transfer_in' }
      amount { 75.00 }
      description { 'Transfer received' }
    end

    trait :transfer_out do
      transaction_type { 'transfer_out' }
      amount { -75.00 }
      description { 'Transfer sent' }
    end
  end
end
