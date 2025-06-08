# frozen_string_literal: true

class User < ApplicationRecord
  has_many :transactions, dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :balance, presence: true,
                      numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_email

  def deposit!(amount, description: nil)
    BalanceOperationService.deposit(user: self, amount: amount, description: description)
  end

  def withdraw!(amount, description: nil)
    BalanceOperationService.withdraw(user: self, amount: amount, description: description)
  end

  def transfer_to_email!(to_email, amount, description: nil)
    TransferService.transfer_by_email(from_user: self, to_email: to_email, amount: amount, description: description)
  end

  def transaction_history(limit: 10)
    transactions.recent.limit(limit)
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip if email.present?
  end
end
