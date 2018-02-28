class User < ActiveRecord::Base
  belongs_to :network
  has_many :packs
  has_many :downloads
end
