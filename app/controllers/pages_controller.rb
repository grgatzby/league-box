class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[home rules sitemap staff]

  def home
    @box = my_own_box(current_round(current_user.club_id)) if current_user
  end

  def staff
    # deprecated code: now moved to ContactsController # new
    if current_user == @admin
      @referees = User.where(role: "referee")
    end
  end
end
