class CreateCommissions < ActiveRecord::Migration[5.2]
  def change
    create_table :commissions do |t|
      t.string :account_type, limit: 10, null: false
      t.bigint :member_id, null: false
      t.string :friend_uid, limit: 10, null: false
      t.decimal :earn_amount, precision: 32, scale: 16, null: false
      t.string :currency_id, limit: 10, null: false
      t.bigint :parent_id, null: false
      t.datetime :parent_created_at, null: false

      t.timestamps
    end
    add_index :commissions, %i[account_type]
    add_index :commissions, %i[member_id]
    add_index :commissions, %i[currency_id]
    add_index :commissions, %i[account_type member_id]
    add_index :commissions, %i[account_type currency_id]
    add_index :commissions, %i[member_id currency_id]
    add_index :commissions, %i[account_type member_id currency_id]
  end
end
