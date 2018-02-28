class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.timestamps null: false

      t.references :network, foreign_key: true
      t.string :name, limit: 128, null: false
      t.boolean :online
      t.integer :pack_count
      t.integer :open_slot_count
      t.integer :total_slot_count
      t.integer :queue_size
      t.integer :queued_count
      t.string :min_speed
      t.string :max_speed
      t.string :current_speed
      t.string :offered_size
      t.string :transferred_size
    end

    add_index :users, %i[network_id name], unique: true
  end
end
