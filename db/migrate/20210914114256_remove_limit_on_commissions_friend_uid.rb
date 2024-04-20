class RemoveLimitOnCommissionsFriendUid < ActiveRecord::Migration[5.2]
  def up
    change_column :commissions, :friend_uid, :string, null: false
  end

  def down
    change_column :commissions, :friend_uid, :string, limit: 10, null: false
  end
end
