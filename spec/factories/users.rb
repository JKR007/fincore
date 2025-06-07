# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    balance { 0.0 }

    trait :with_balance do
      balance { 100.50 }
    end

    trait :with_large_balance do
      balance { 10_000.00 }
    end

    trait :with_zero_balance do
      balance { 0.0 }
    end
  end
end
