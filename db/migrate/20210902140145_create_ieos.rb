class CreateIeos < ActiveRecord::Migration[5.2]
  def change
    create_table :ieos do |t|
      t.string :currency_id, limit: 10, null: false
      t.string :main_payment_currency, limit: 10, null: false
      t.decimal :price, precision: 32, scale: 16, null: false
      t.json :payment_currencies, null: false
      t.decimal :min_amount, precision: 32, scale: 16, null: false
      t.string :state, limit: 32, default: "enabled", null: false
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false

      t.timestamps
    end
    add_index :ieos, %i[currency_id]
    add_index :ieos, %i[main_payment_currency]
    add_index :ieos, %i[state]
  end
end
