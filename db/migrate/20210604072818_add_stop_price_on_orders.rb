class AddStopPriceOnOrders < ActiveRecord::Migration[5.2]
  def change
    add_column :orders, :stop_price, :decimal, precision: 32, scale: 16, null: true, after: :price
  end
end
