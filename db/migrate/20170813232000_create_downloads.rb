class CreateDownloads < ActiveRecord::Migration
  def change
    create_table :downloads do |t|
      t.timestamps null: false

      t.string :name
      t.string :status
      t.integer :size
      t.integer :position
      t.string :ip
      t.integer :port
    end
  end
end
