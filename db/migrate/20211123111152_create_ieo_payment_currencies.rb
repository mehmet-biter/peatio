class CreateIeoPaymentCurrencies < ActiveRecord::Migration[5.2]
  def change
    create_table :ieo_payment_currencies do |t|
      t.string :currency_id, limit: 10, null: false
      t.bigint :ieo_id, null: false

      t.timestamps
    end

    add_index :ieo_payment_currencies, %i[currency_id ieo_id], unique: true
  end
end
