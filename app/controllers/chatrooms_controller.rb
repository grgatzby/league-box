class ChatroomsController < ApplicationController
  def show
    # display the chatroom
    # method is accessed from either the navbar, or the show_referee or manage_my_box view pages
    @current_box = current_user.user_box_scores.map(&:box).last
    if params[:chatroom]
      # coming from the form in show_referee view page
      # [1..-1] to remove the first hash tag in the name
      @chatroom = Chatroom.find_by(name: params[:chatroom][1..-1])
    elsif params[:id] == "0"
      # defines the list of chatrooms available for the referee or the admin
      # to chose from in the form. For a referee: only those from his club
      if current_user == @admin
        @chatrooms = Chatroom.all
      else
        @chatrooms = Chatroom.select do |chatroom|
          box = chatroom.box
          club = box.round.club
          club == @current_user.club
        end
      end
      # adding the hash tag in front of the chatroom names (for display in the form)
      @chatrooms = @chatrooms.map { |chatroom| "##{chatroom.name}" }
    else
      # coming from the navbar or manage_my_box view page
      @chatroom = Chatroom.find(params[:id])
      if @chatroom != @general_chatroom &&
         @chatroom.box.user_box_scores
                  .select { |user_box_score| user_box_score.user_id == current_user.id }.empty?
        flash[:notice] = "You have no access to this chatroom."
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
