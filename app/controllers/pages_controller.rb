class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[home rules sitemap my_club]

  def home
    @box = my_own_box(current_round(current_user.club_id)) if current_user
    @path = {}
    if current_user
      # paths associated with the links in the home page
      @path["01"] = my_scores_path(0)
      @path["02"] = boxes_path
      @path["03a"] = box_list_path(@box || 0)
      @path["03b"] = box_path(@box || 0)
      @path["04a"] = user_box_scores_path
      @path["04b"] = index_league_path
    end
    @path["05"] = rules_path
    @path["06"] = new_contact_path

  end

  def rules
      @rounds_dropdown = @club.rounds.map { |round| rounds_dropdown(round) }.sort.reverse # dropdown in the select round form
      @rounds = @club.rounds
      # Show images grouped by club - admin sees all, others see only accessible to their club
      if current_user&.role == "admin"
        all_images = GalleryImage.joins(:club).order('clubs.name ASC, gallery_images.created_at DESC')
        @gallery_images_by_club = all_images.group_by(&:club)
        @is_admin = true
      elsif current_user
        @gallery_images = GalleryImage.accessible_to_club(current_user.club_id).includes(:club).order(created_at: :desc)
        @is_admin = false
      else
        # For non-authenticated users, show images from sample club
        @gallery_images = GalleryImage.accessible_to_club(@club.id).includes(:club).order(created_at: :desc)
        @is_admin = false
      end
  end

  def my_club
    # similar to ContactsController # new
    if current_user == @admin
      # @referees = User.where(role: "referee") #TO DO : role includes 'referee' or 'player referee'
      @referees = User.where("role like ?", "%referee%")
      # Load all players grouped by club for admin view
      all_players = User.joins(:club)
                        .where("role IN (?)", ["player", "player referee"])
                        .order('clubs.name ASC, users.last_name ASC, users.first_name ASC')
      @players_by_club = all_players.group_by(&:club)
      @is_admin = true
    else
      # Load players for a single club (filtered client-side)
      @players = User.where(club_id: @club.id)
                     .where("role IN (?)", ["player", "player referee"])
                     .order(:last_name, :first_name)
      @is_admin = false
    end
  end
end
