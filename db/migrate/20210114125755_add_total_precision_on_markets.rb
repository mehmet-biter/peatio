class AddTotalPrecisionOnMarkets < ActiveRecord::Migration[5.2]
  def change
    add_column :markets, :total_precision, :integer, after: :price_precision
  end
end
