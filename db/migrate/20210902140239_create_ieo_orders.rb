class CreateIeoOrders < ActiveRecord::Migration[5.2]
  def change
    create_table :ieo_orders do |t|
      t.binary :uuid, limit: 16, null: false
      t.bigint :ieo_id, null: false
      t.bigint :member_id, null: false
      t.string :bid, limit: 10, null: false
      t.string :ask, limit: 10, null: false
      t.decimal :price, precision: 32, scale: 16, null: false
      t.decimal :quantity, precision: 32, scale: 16, null: false
      t.decimal :bouns, precision: 32, scale: 16, null: false
      t.integer :state, null: false

      t.timestamps
    end
    add_index :ieo_orders, %i[member_id]
    add_index :ieo_orders, %i[state]
    add_index :ieo_orders, %i[state bid ask]
    add_index :ieo_orders, %i[state bid]
    add_index :ieo_orders, %i[state ask]
    add_index :ieo_orders, %i[state member_id]
    add_index :ieo_orders, %i[updated_at]
    add_index :ieo_orders, %i[uuid], unique: true
  end
end
