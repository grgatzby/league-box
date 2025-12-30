class GalleryImagesController < ApplicationController
  before_action :set_gallery_image, only: %i[show edit update destroy]
  before_action :set_clubs_for_selection, only: %i[new edit]

  def index
    # Admin can see all images grouped by club
    if current_user&.role == "admin"
      all_images = GalleryImage.joins(:club).order('clubs.name ASC, gallery_images.created_at DESC')
      @gallery_images_by_club = all_images.group_by(&:club)
      @is_admin = true
    elsif current_user
      # Regular users see images accessible to their club
      @gallery_images = GalleryImage.accessible_to_club(current_user.club_id).order(created_at: :desc)
      @is_admin = false
    else
      # For non-authenticated users, show images from sample club
      sample_club = Club.find_by(name: "your tennis club")
      @gallery_images = sample_club ? GalleryImage.accessible_to_club(sample_club.id).order(created_at: :desc) : GalleryImage.none
      @is_admin = false
    end
  end

  def new
    @gallery_image = GalleryImage.new
    # Set default club to current user's club
    if current_user
      @gallery_image.club = current_user.club
      # Set default accessible clubs to current user's club
      @gallery_image.accessible_club_ids = [current_user.club_id]
    else
      @gallery_image.accessible_club_ids = []
    end
  end

  def create
    @gallery_image = GalleryImage.new(gallery_image_params)
    # Set club to current user's club if not admin or not specified
    unless current_user&.role == "admin" && gallery_image_params[:club_id].present?
      @gallery_image.club = current_user.club if current_user
    end
    # CarrierWave will upload during save, and model.id should be available
    # The public_id method in the uploader will use model.id if present
    if @gallery_image.save
      redirect_to gallery_images_path, notice: t('.success')
    else
      set_clubs_for_selection
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    update_params = gallery_image_params.dup
    # Only allow club_id change if user is admin
    unless current_user&.role == "admin"
      update_params.delete(:club_id)
    end
    if @gallery_image.update(update_params)
      redirect_to gallery_images_path, notice: t('.success')
    else
      set_clubs_for_selection
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @gallery_image.destroy
    redirect_to gallery_images_path, notice: t('.success')
  end

  private

  def set_gallery_image
    @gallery_image = GalleryImage.find(params[:id])
  end

  def gallery_image_params
    params.require(:gallery_image).permit(:image, :caption, :club_id, accessible_club_ids: [])
  end

  def set_clubs_for_selection
    if current_user&.role == "admin"
      # Admin can see all clubs
      @clubs = Club.all.reject { |club| club.name == "your tennis club" }
      @clubs.unshift(Club.find_by(name: "your tennis club")) if Club.find_by(name: "your tennis club")
    else
      # Regular users can only see their own club
      @clubs = current_user ? [current_user.club] : []
    end
  end
end
