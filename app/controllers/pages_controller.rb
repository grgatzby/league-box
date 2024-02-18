class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[home rules sitemap staff]

  def home
    @box = my_own_box(current_round(current_user.club_id)) if current_user
    @path = {}
    if current_user
      # paths associated with the links in the home page
      @path["01"] = my_scores_path(0)
      @path["02"] = boxes_path
      @path["03a"] = box_list_path(@box || 0)
      @path["03b"] = box_path(@box || 0)
      @path["04"] = user_box_scores_path
    end
    @path["05"] = rules_path
  end

  def staff
    # similar to ContactsController # new
    if current_user == @admin
      # @referees = User.where(role: "referee") #TO DO : role includes 'referee' or 'player referee'
      @referees = User.where("role like ?", "%referee%")
    end
  end
end
