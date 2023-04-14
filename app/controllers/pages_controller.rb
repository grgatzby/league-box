class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :overview]
  def home
    @club = current_user ? current_user.club : Club.first
  end
end
