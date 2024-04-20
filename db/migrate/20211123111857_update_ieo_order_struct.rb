class UpdateIeoOrderStruct < ActiveRecord::Migration[5.2]
  def change
    remove_column :ieo_orders, :ask
    remove_column :ieo_orders, :bid

    add_column :ieo_orders, :payment_currency_id, :string, limit: 10, null: false, after: :member_id
  end
end
