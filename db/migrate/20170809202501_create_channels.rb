class CreateChannels < ActiveRecord::Migration
  def change
    create_table :channels do |t|
      t.timestamps null: false

      t.references :network, foreign_key: true
      t.string :name, limit: 64, null: false
    end

    add_index :channels, %i[network_id name], unique: true
  end
end
