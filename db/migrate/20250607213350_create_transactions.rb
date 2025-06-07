# frozen_string_literal: true

class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :transaction_type, null: false
      t.string :description
      t.decimal :balance_before, precision: 15, scale: 2, null: false
      t.decimal :balance_after, precision: 15, scale: 2, null: false

      t.timestamps
    end

    add_index :transactions, :transaction_type
    add_index :transactions, :created_at
  end
end
