class AddPassiveToUsers < ActiveRecord::Migration
  def up
    add_column :users, :passive, :boolean
  end
end
