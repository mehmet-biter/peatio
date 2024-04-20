class pleaseChangeMembersReferralUidToString < ActiveRecord::Migration[5.2]
  def up
    change_column :members, :referral_uid, :string, limit: 32
  end

  def down
    change_column :members, :referral_uid, :integer
  end
end
