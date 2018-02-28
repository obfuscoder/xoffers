class CreateNetworks < ActiveRecord::Migration
  def change
    create_table :networks do |t|
      t.timestamps null: false

      t.string :name, limit: 32, null: false
    end

    add_index :networks, :name, unique: true
  end
end
