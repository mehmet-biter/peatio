class CreateReleaseCommissions < ActiveRecord::Migration[5.2]
  def change
    create_table :release_commissions do |t|
      t.string :account_type, limit: 10, null: false
      t.bigint :member_id, null: false
      t.decimal :earned_btc, precision: 32, scale: 16, null: false
      t.integer :friend_trade, null: false
      t.integer :friend, null: false

      t.timestamps
    end
    add_index :release_commissions, %i[account_type]
    add_index :release_commissions, %i[member_id]
    add_index :release_commissions, %i[member_id account_type]
  end
end
