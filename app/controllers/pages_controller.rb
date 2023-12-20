class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[home rules sitemap staff]

  def staff
    # deprecated code: now moved to ContactsController # new
    if current_user == @admin
      @referees = User.where(role: "referee")
    end
  end
end
