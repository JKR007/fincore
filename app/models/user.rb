# frozen_string_literal: true

class User < ApplicationRecord
  has_many :transactions, dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :balance, presence: true,
                      numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email&.downcase&.strip if email.present?
  end
end
