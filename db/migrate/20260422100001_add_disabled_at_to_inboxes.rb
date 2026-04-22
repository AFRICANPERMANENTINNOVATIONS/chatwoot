class AddDisabledAtToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :disabled_at, :datetime
    add_index :inboxes, :disabled_at, where: 'disabled_at IS NOT NULL',
                                      name: 'index_inboxes_on_disabled_at'
  end
end
