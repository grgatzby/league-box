class ChatroomsController < ApplicationController
  # Chatrooms have a one to one relation wth Boxes (has_one :box)
  REFEREE = ["referee", "player referee"]

  def show
    set_club_round # set variables @club and @round (ApplicationController)
    # choose/display a chatroom
    # this method is accessed from either [A, B] itself (form), [C] the navbar dropdown, or [D] My scores view
    @current_box = current_user.user_box_scores.map(&:box).last
    if params[:chatroom]
      # [A] display a chatroom after selecting a chatroom name from the chatrooms/show dropdown
      # [1..] removes the first character '#' of the name (same as [1..-1])
      @chatroom = Chatroom.find_by(name: params[:chatroom][1..])
      @box_nb = @chatroom.box.box_number
      @round = @chatroom.box.round
      @round_nb = round_label(@round)
    elsif (params[:round] && current_user.role == "player") || params[:box]
      # [B] display a chatroom after selecting a club, a round and a box number
      # either select an open chatroom or create (open) a chatroom
      club = Club.find_by(name: params[:club])
      round = Round.find_by(club_id: club.id, start_date: params[:round].to_date)
      if current_user.role == "player"
        @box = my_own_box(round) # players don't choose a box within a round
      else
        @box = Box.find_by(box_number: params[:box], round_id: round.id) # admin/referees choose a box number
      end
      chatroom_name = chatroom_name(@box)
      if Chatroom.find_by(name: chatroom_name)
        # chatroom already open, select it
        @chatroom = Chatroom.find_by(name: chatroom_name)
      else
        # chatroom not opened yet, create it
        flash[:notice] = t('.chatroom_created_flash')
        @chatroom = Chatroom.create(name: chatroom_name)
        @box.update(chatroom_id: @chatroom.id)
      end
      @box_nb = @chatroom.box.box_number
      @round = @chatroom.box.round
      @round_nb = round_label(@round)
    elsif params[:id]
      if params[:id] == "0"
        # [C] coming from the navbar dropdown: display the forms (a dropdown list of available chatrooms
        # and a nested form of club/round/box numbers)
        # [a] define list of available chatrooms in the first form
        if current_user == @admin
          # admin can access all existing chatrooms (including the #general chatroom)
          @chatrooms = Chatroom.all
        # elsif current_user.role == "referee" || current_user.role == "player referee"
        elsif REFEREE.include?(current_user.role)
          # referees have access to all chatrooms from their club + the #general chatroom
          @chatrooms = Chatroom.select do |chatroom|
            chatroom.box.round.club == current_user.club
          end
          @chatrooms.push(@general_chatroom) unless @chatrooms.include?(@general_chatroom)
        else
          # player can only access chatrooms from their current or previous boxes
          @chatrooms = Chatroom.select do |chatroom|
            my_box?(chatroom.box)
          end
        end
        # prepend the '#' character to the chatroom names (for the form display)
        @chatrooms = @chatrooms.map { |chatroom| "##{chatroom.name}" }

        # [b] create a hash containing clubs, rounds start_date and box numbers from
        # nested active records to prepopulate the chatroom selection form
        @data = Club.all.includes(rounds: :boxes).as_json(
                        include: { rounds: { include: { boxes: { only: [:box_number] } }, only: [:start_date] } },
                        only: [:id, :name])
        # transform the hash format convention {"round" => value} to {round: value} and exclude the sample club
        @data.each { |field| field.deep_symbolize_keys! }.reject! { |a| a[:id] == @sample_club.id }
        @clubs = @data.map { |club| club[:name] }
      elsif Chatroom.exists?(params[:id])
        # [D] coming from my_scores view (players): display the box chatroom
        @chatroom = Chatroom.find(params[:id])
        @box_nb = @chatroom.box.box_number
        if @chatroom.box.user_box_scores.select { |user_box_score| user_box_score.user_id == current_user.id }.empty?
          # chatroom not available to current user
          flash[:notice] = t('.no_access_flash')
          redirect_back(fallback_location: current_user.role == "player" ? my_scores_path(0) : root_path)
        end
      end
    else
      # chatroom Id does not exist (bad url)
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
