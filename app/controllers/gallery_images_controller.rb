class GalleryImagesController < ApplicationController
  before_action :set_gallery_image, only: %i[show edit update destroy]

  def index
    @gallery_images = GalleryImage.order(created_at: :desc)
  end

  def new
    @gallery_image = GalleryImage.new
  end

  def create
    @gallery_image = GalleryImage.new(gallery_image_params)
    if @gallery_image.save
      redirect_to gallery_images_path, notice: t('.success')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @gallery_image.update(gallery_image_params)
      redirect_to gallery_images_path, notice: t('.success')
    else
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
    params.require(:gallery_image).permit(:image, :caption)
  end
end
