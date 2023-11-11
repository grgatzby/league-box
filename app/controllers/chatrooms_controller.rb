class ChatroomsController < ApplicationController
  def show
    # display the chatroom
    # method is accessed from either the navbar, or the show_referee or manage_my_box view pages
    @current_box = current_user.user_box_scores.map(&:box).last
    if params[:chatroom]
      # coming from the form in show_referee view page ([1..-1] removes the first character '#' of the name)
      @chatroom = Chatroom.find_by(name: params[:chatroom][1..-1])
    elsif params[:id] == "0"
      # defines the list of chatrooms available for the referee or the admin to select
      # in the form. For a referee: only those from his club
      if current_user == @admin
        @chatrooms = Chatroom.all
      else
        @chatrooms = Chatroom.select do |chatroom|
          box = chatroom.box
          club = box.round.club
          club == current_user.club
        end
      end
      # add the '#' in front of the chatroom names (for display in the form)
      @chatrooms = @chatrooms.map { |chatroom| "##{chatroom.name}" }
    else
      # coming from the navbar or manage_my_box view page
      @chatroom = Chatroom.find(params[:id])
      if @chatroom != @general_chatroom &&
         @chatroom.box.user_box_scores
                  .select { |user_box_score| user_box_score.user_id == current_user.id }.empty?
        flash[:notice] = t('.no_access_flash')
        redirect_back(fallback_location: manage_my_box_path(0))
      end
    end
    # instantiate @message for the new massage form
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
