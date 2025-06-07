# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.decimal :balance, precision: 15, scale: 2, default: 0.00, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_check_constraint :users, 'balance >= 0', name: 'positive_balance'
  end
end
