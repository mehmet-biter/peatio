class UpdateIeoStruct < ActiveRecord::Migration[5.2]
  def change
    add_column :ieos, :executed_quantity, :decimal, precision: 32, scale: 16, null: false, after: :price
    add_column :ieos, :origin_quantity, :decimal, precision: 32, scale: 16, null: false, after: :executed_quantity
    add_column :ieos, :banner_url, :string, null: false, after: :end_time
  end
end
