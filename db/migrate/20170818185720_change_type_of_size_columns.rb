class ChangeTypeOfSizeColumns < ActiveRecord::Migration
  def up
    change_column :downloads, :size, :bigint
    change_column :downloads, :position, :bigint
  end
end
