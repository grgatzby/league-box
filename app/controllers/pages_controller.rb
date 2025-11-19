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
      @path["04a"] = user_box_scores_path
      @path["04b"] = index_league_path
    end
    @path["05"] = rules_path
    @path["06"] = new_contact_path

    #@langue = request.env['HTTP_ACCEPT_LANGUAGE'].to_s.scan(/^[a-z]{2}/).first


  end

  def staff
    # similar to ContactsController # new
    if current_user == @admin
      # @referees = User.where(role: "referee") #TO DO : role includes 'referee' or 'player referee'
      @referees = User.where("role like ?", "%referee%")
    end
  end

  def my_details
    #on 10/02/2025 replaced pages#my_details with preferences#new and preferences#edit
    #this method should be deleted (as the corresponding route)
    @preference = current_user.preference || Preference.new(user_id: current_user.id)
  end
end
