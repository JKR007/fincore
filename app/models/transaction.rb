# frozen_string_literal: true

class Transaction < ApplicationRecord
  belongs_to :user

  TRANSACTION_TYPES = %w[deposit withdrawal transfer_in transfer_out].freeze

  validates :amount, presence: true, numericality: { other_than: 0 }
  validates :transaction_type, presence: true, inclusion: { in: TRANSACTION_TYPES }
  validates :balance_before, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :balance_after, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }

  def deposit?
    transaction_type == "deposit"
  end

  def withdrawal?
    transaction_type == "withdrawal"
  end

  def transfer?
    %w[transfer_in transfer_out].include?(transaction_type)
  end
end
