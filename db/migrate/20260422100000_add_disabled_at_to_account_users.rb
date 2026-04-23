class AddDisabledAtToAccountUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :account_users, :disabled_at, :datetime
    add_index :account_users, :disabled_at, where: 'disabled_at IS NOT NULL',
                                            name: 'index_account_users_on_disabled_at'
  end
end
