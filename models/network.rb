class Network < ActiveRecord::Base
  has_many :servers
  has_many :channels
  has_many :users
end
