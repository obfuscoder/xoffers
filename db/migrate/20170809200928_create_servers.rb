class CreateServers < ActiveRecord::Migration
  def change
    create_table :servers do |t|
      t.timestamps null: false

      t.references :network, foreign_key: true
      t.string :address, limit: 128, null: false
      t.integer :port
    end

    add_index :servers, :address, unique: true
  end
end
