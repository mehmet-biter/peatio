class UpdateIeoData < ActiveRecord::Migration[5.2]
  def change
    add_column :ieos, :data, :string, null: false, after: :end_time
  end
end
