class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :rules, :sitemap, :staff]

  def staff
    if current_user == @admin
      @referees = User.where(role: "referee")
    end
  end
end
