class ChatroomsController < ApplicationController
  # Chatrooms have a one to one relation wth Boxes (has_one :box)
  def show
    set_club_round # set variables @club and @round (ApplicationController)
    # display a chatroom
    # this method is accessed from either the navbar, or the show_list or my_scores view pages
    @current_box = current_user.user_box_scores.map(&:box).last
    if params[:chatroom]
      # coming from the chatrooms/show dropdown form: params[:chatroom] is defined
      # @chatroom = Chatroom.find_by(name: params[:chatroom][1..-1]) # [1..-1] removes the first character '#' of the name
      @chatroom = Chatroom.find_by(name: params[:chatroom][1..]) # [1..] removes the first character '#' of the name
      @box_nb = @chatroom.box.box_number
      @round = @chatroom.box.round
      @round_nb = round_number(@round)
    elsif (params[:round] && current_user.role == "player") || params[:box] # after selecting a club, a round and a box number, select or create a chatroom
      club = Club.find_by(name: params[:club])
      round = Round.find_by(club_id: club.id, start_date: params[:round].to_date)
      if current_user.role == "player"
        @box = my_own_box(round)
      else
        @box = Box.find_by(box_number: params[:box], round_id: round.id)
      end
      chatroom_name = "#{@box.round.club.name} - R#{round_number(@box.round)}:B#{format('%02d', @box.box_number)}"
      if Chatroom.find_by(name: chatroom_name)
        @chatroom = Chatroom.find_by(name: chatroom_name)
      else
        flash[:notice] = t('.chatroom_created_flash')
        @chatroom = Chatroom.create(name: chatroom_name)
        @box.update(chatroom_id: @chatroom.id)
      end
      @box_nb = @chatroom.box.box_number
      @round = @chatroom.box.round
      @round_nb = round_number(@round)
      # clean params when hitting back to reset the forms
    elsif params[:id]
      if params[:id] == "0" # coming from the navbar: create the dropdown list of chatrooms available
        if current_user == @admin # admin: all existing chatrooms (including the #general chatroom)
          @chatrooms = Chatroom.all
        elsif current_user.role == "referee" # all chatrooms from the club + the #general chatroom
          @chatrooms = Chatroom.select do |chatroom|
            chatroom.box.round.club == current_user.club
          end
          @chatrooms.push(@general_chatroom) unless @chatrooms.include?(@general_chatroom)
        else # player: only chatrooms from current or previous boxes
          @chatrooms = Chatroom.select do |chatroom|
            my_box?(chatroom.box)
          end
        end
        # add the '#' character in front of the chatroom names (for displaying in the form)
        @chatrooms = @chatrooms.map { |chatroom| "##{chatroom.name}" }
        # create a hash containing clubs, rounds start_date and box numbers to prepare for the form
        @data = Club.all.includes(rounds: :boxes).as_json(
                        include: { rounds: { include: { boxes: { only: [:box_number] } }, only: [:start_date] } },
                        only: [:id, :name])
        # transform the hash {"round" => value} to {round: value}
        @data.each { |field| field.deep_symbolize_keys! }.reject! { |a| a[:id] == @sample_club.id }
        @clubs = @data.map { |club| club[:name] }
      elsif Chatroom.exists?(params[:id]) # coming from the navbar or my_scores view page
        @chatroom = Chatroom.find(params[:id])
        @box_nb = @chatroom.box.box_number
        if @chatroom.box.user_box_scores.select { |user_box_score| user_box_score.user_id == current_user.id }.empty?
          # chatroom not available to current user
          flash[:notice] = t('.no_access_flash')
          redirect_back(fallback_location: current_user.role == "player" ? my_scores_path(0) : root_path)
        end
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
