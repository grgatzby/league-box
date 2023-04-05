class UserBoxScore < ApplicationRecord
  belongs_to :user
  belongs_to :box
end
