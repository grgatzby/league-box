class Chatroom < ApplicationRecord
  has_many :messages, dependent: :destroy
  has_one :box
  has_many :chatroom_reads, dependent: :destroy
  has_many :read_by_users, through: :chatroom_reads, source: :user

  # validates :box, presence: true
  validates :name, presence: true
  validates :name, uniqueness: true

  def users_with_access
    users = []
    admin = User.find_by(role: "admin")
    users << admin if admin

    if name == "general"
      # General chatroom: admin + all referees
      referees = User.where("role LIKE ?", "%referee%")
      users.concat(referees)
    elsif box
      # Regular chatroom: admin + players in box + referees from same club
      # Players in the box
      box.user_box_scores.includes(:user).each do |user_box_score|
        users << user_box_score.user unless users.include?(user_box_score.user)
      end

      # Referees from the same club
      club = box.round.club
      referees = User.where(club_id: club.id).where("role LIKE ?", "%referee%")
      referees.each do |referee|
        users << referee unless users.include?(referee)
      end
    end

    users.uniq
  end
end
