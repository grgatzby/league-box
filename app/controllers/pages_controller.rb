class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[home rules sitemap staff]

  def home
    @box = my_own_box(current_round(current_user.club_id)) if current_user
    @path = {}
    if current_user
      @path["01"] = my_scores_path(@box || 0)
      @path["02"] = boxes_path
      @path["03a"] = box_list_path(@box || 0)
      @path["03b"] = box_path(@box || 0)
      @path["04"] = user_box_scores_path
    end
  end

  def staff
    # deprecated code: now moved to ContactsController # new
    if current_user == @admin
      @referees = User.where(role: "referee")
    end
  end
end
