class ChatroomsController < ApplicationController
  # Chatrooms have a one to one relation wth Boxes (has_one :box)
  def show
    set_club_round # set variables @club and @round (ApplicationController)
    # display a chatroom
    # this method is accessed from either the navbar, or the show_list or my_scores view pages
    @current_box = current_user.user_box_scores.map(&:box).last
    if params[:chatroom]
      # coming from the chatrooms/show dropdown form (admin/referee): params[:chatroom] is defined
      # @chatroom = Chatroom.find_by(name: params[:chatroom][1..-1]) # [1..-1] removes the first character '#' of the name
      @chatroom = Chatroom.find_by(name: params[:chatroom][1..]) # [1..] removes the first character '#' of the name
      @box_nb = @chatroom.box.box_number
      @round = @chatroom.box.round
      @round_nb = round_number(@round)
    elsif params[:id] == "0" # define the dropdown list of chatrooms available for the referee or the admin
      if current_user == @admin # if the admin: all chatrooms
        @chatrooms = Chatroom.all
      else # if a Referee, only those from his club + the #general chatroom
        @chatrooms = Chatroom.select do |chatroom|
          box = chatroom.box
          club = box.round.club
          club == current_user.club
        end
        @chatrooms.push(@general_chatroom) unless @chatrooms.include?(@general_chatroom)
      end
      # add the '#' in front of the chatroom names (for display in the form)
      @chatrooms = @chatrooms.map { |chatroom| "##{chatroom.name}" }
    elsif Chatroom.exists?(params[:id])
      # coming from the navbar or my_scores view page
      @chatroom = Chatroom.find(params[:id])
      @box_nb = @chatroom.box.box_number
      if @chatroom.box.user_box_scores.select { |user_box_score| user_box_score.user_id == current_user.id }.empty?
        # chatroom not available to current user
        flash[:notice] = t('.no_access_flash')
        redirect_back(fallback_location: current_user.role == "player" ? my_scores_path(0) : root_path)
      end
    else
      # chatroom Id does not exist
      flash[:notice] = t('.no_chatroom_flash')
      redirect_back(fallback_location: current_user.role == "player" ? my_scores_path(0) : root_path)
    end
    # instantiate @message for the new message form
    @message = Message.new
  end

  def new
    @chatroom = Chatroom.new
  end

  def create
    @chatroom = Chatroom.new(params[:box_id])
    redirect_to chatroom_path(@chatroom)
  end
end
