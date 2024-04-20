class RemovePaymentCurrenciesIeos < ActiveRecord::Migration[5.2]
  def change
    remove_column :ieos, :payment_currencies
  end
end
