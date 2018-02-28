class AddUserToDownloads < ActiveRecord::Migration
  def up
    add_reference :downloads, :user
  end
end
