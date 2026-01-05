class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  belongs_to :club
  has_many :user_match_scores
  has_many :user_box_scores
  has_many :messages
  has_one :preference
  has_many :chatroom_reads, dependent: :destroy
  has_many :read_chatrooms, through: :chatroom_reads, source: :chatroom
  mount_uploader :profile_picture, ProfilePictureUploader

  def has_unread_chatrooms?
    Chatroom.all.any? do |chatroom|
      next unless chatroom.users_with_access.include?(self)

      chatroom_read = chatroom_reads.find_by(chatroom: chatroom)
      last_read_at = chatroom_read&.last_read_at

      # If never read, check if there are any messages
      if last_read_at.nil?
        chatroom.messages.exists?
      else
        # Check if there are messages created after last_read_at
        chatroom.messages.where("created_at > ?", last_read_at).exists?
      end
    end
  end
end
