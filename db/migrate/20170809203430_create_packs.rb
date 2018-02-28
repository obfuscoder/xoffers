class CreatePacks < ActiveRecord::Migration
  def change
    create_table :packs do |t|
      t.timestamps null: false

      t.references :user, foreign_key: true
      t.integer :number, null: false
      t.string :name
      t.integer :download_count
      t.string :size
    end

    add_index :packs, %i[user_id number], unique: true
  end
end
