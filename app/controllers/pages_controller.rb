# Pages Controller
# Handles public and authenticated page views (home, rules, my_club).
# Manages club/player information display and updates (logo, banner, website, profile pictures).
# Public pages: home, rules, sitemap, my_club (skip authentication)
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[home rules sitemap my_club]

  # Display home page with navigation paths
  # Sets up path hash for various navigation links on the home page
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

  # Display rules page with gallery images
  # Shows gallery images grouped by club with different access levels based on user role
  # Admin sees all images, authenticated users see their club's images, guests see sample club images
  def rules
    @rounds_dropdown = @club.rounds.map { |round| rounds_dropdown(round) }.sort.reverse # dropdown in the select round form
    @rounds = @club.rounds
    # Show images grouped by club - admin sees all, others see only accessible to their club
      if current_user&.role == "admin"
        all_images = GalleryImage.joins(:club).order('clubs.name ASC, gallery_images.created_at DESC')
        @gallery_images_by_club = all_images.group_by(&:club)
        @is_admin = true
      elsif current_user
        # Regular users see images accessible to their club, grouped by club
        accessible_images = GalleryImage.accessible_to_club(current_user.club_id).includes(:club).order('clubs.name ASC, gallery_images.created_at DESC')
        @gallery_images_by_club = accessible_images.group_by(&:club)
        @is_admin = false
      else
        # For non-authenticated users, show images from sample club, grouped by club
        accessible_images = GalleryImage.accessible_to_club(@club.id).includes(:club).order('clubs.name ASC, gallery_images.created_at DESC')
        @gallery_images_by_club = accessible_images.group_by(&:club)
        @is_admin = false
      end
  end

  # Display club information page (players, referees, gallery images)
  # Admin sees all clubs' data, regular users see only their club's data
  # Similar functionality to ContactsController # new
  def my_club
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

    # Load gallery images grouped by club (similar to rules method)
    if current_user&.role == "admin"
      all_images = GalleryImage.joins(:club).order('clubs.name ASC, gallery_images.created_at DESC')
      @gallery_images_by_club = all_images.group_by(&:club)
    elsif current_user
      # Regular users see images accessible to their club, grouped by club
      accessible_images = GalleryImage.accessible_to_club(current_user.club_id).includes(:club).order('clubs.name ASC, gallery_images.created_at DESC')
      @gallery_images_by_club = accessible_images.group_by(&:club)
    else
      # For non-authenticated users, show images from sample club, grouped by club
      accessible_images = GalleryImage.accessible_to_club(@club.id).includes(:club).order('clubs.name ASC, gallery_images.created_at DESC')
      @gallery_images_by_club = accessible_images.group_by(&:club)
    end
  end

  # Update club logo and banner (admin or referee only)
  # Referees can only update their own club, admin can update any club
  def update_club
    # Authorization check: only admin or referees can update club logo/banner
    unless current_user && (current_user.role&.include?("referee") || current_user == @admin)
      flash[:alert] = t("pages.update_club.unauthorized")
      redirect_to my_club_path
      return
    end

    begin
      club = if current_user == @admin && params[:club_id].present?
               Club.find(params[:club_id])
             else
               current_user.club
             end

      if club.update(club_params)
        flash[:notice] = t("pages.update_club.success")
      else
        flash[:alert] = t("pages.update_club.error")
      end
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = t("pages.update_club.club_not_found")
    end

    redirect_to my_club_path
  end

  # Update user profile picture (admin only)
  # Allows admin to change any user's profile picture
  def update_user_profile_picture
    # Authorization check: only admin can update profile pictures
    unless current_user == @admin
      flash[:alert] = t("pages.update_user_profile_picture.unauthorized", default: "You are not authorized to update profile pictures.")
      redirect_to my_club_path
      return
    end

    begin
      user = User.find(params[:id])

      if user.update(user_profile_picture_params)
        flash[:notice] = t("pages.update_user_profile_picture.success", default: "Profile picture updated successfully.")
      else
        flash[:alert] = t("pages.update_user_profile_picture.error", default: "Error updating profile picture.")
      end
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = t("pages.update_user_profile_picture.user_not_found", default: "User not found.")
    end

    redirect_to my_club_path
  end

  # Update club website (admin or referee only)
  # Handles club selection for admin and preserves club_id in redirect
  # Referees can only update their own club's website
  def update_club_website
    # Authorization check: only admin or referees can update club website
    unless current_user && (current_user.role&.include?("referee") || current_user == @admin)
      flash[:alert] = t("preferences.edit.unauthorized", default: "You are not authorized to update club website.")
      redirect_to edit_preference_path(current_user.preference)
      return
    end

    # If admin is just selecting a club (no website param), redirect back with club_id
    if current_user == @admin && params[:club_id].present? && params[:website].blank?
      redirect_to edit_preference_path(current_user.preference, club_id: params[:club_id])
      return
    end

    begin
      club = if current_user == @admin && params[:club_id].present?
               Club.find(params[:club_id])
             else
               # Referee can only update their own club
               current_user.club
             end

      if club.update(website: params[:website])
        flash[:notice] = t("preferences.edit.website_updated", default: "Club website updated successfully.")
      else
        flash[:alert] = t("preferences.edit.website_error", default: "Error updating club website.")
      end
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = t("preferences.edit.club_not_found", default: "Club not found.")
    end

    # Preserve club_id parameter for admin when redirecting
    redirect_path = if current_user == @admin && params[:club_id].present?
                      edit_preference_path(current_user.preference, club_id: params[:club_id])
                    else
                      edit_preference_path(current_user.preference)
                    end
    redirect_to redirect_path
  end

  private

  # Strong parameters for club updates
  def club_params
    params.require(:club).permit(:logo, :banner, :website)
  end

  # Strong parameters for user profile picture updates
  def user_profile_picture_params
    params.require(:user).permit(:profile_picture)
  end
end
