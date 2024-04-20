class IeoLimitQuantityPerUser < ActiveRecord::Migration[5.2]
  def change
    add_column :ieos, :limit_per_user, :decimal, precision: 32, scale: 16, null: false, after: :origin_quantity
  end
end
