class AddReferralUidOnMembers < ActiveRecord::Migration[5.2]
  def change
    add_column :members, :referral_uid, :integer, after: :group
  end
end
