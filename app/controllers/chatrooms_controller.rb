# Chatrooms Controller
# Handles chatroom display, creation, and deletion.
# Chatrooms have a one-to-one relation with Boxes (has_one :box).
# Manages chatroom access control based on user roles (player, referee, admin).
class ChatroomsController < ApplicationController
  REFEREE = ["referee", "player referee"]

  # Display or create a chatroom
  # Accessible from multiple entry points:
  # [A] Chatroom name selection from dropdown
  # [B] Club/round/box selection from form
  # [C] Navbar dropdown (shows selection form)
  # [D] My scores view or unread chatroom links
  # Automatically creates chatroom if it doesn't exist
  # Marks chatroom as read when displaying
  def show
    # sets variables @club and @round (ApplicationController) for display in the navbar
    set_club_round
    @current_box = current_user.user_box_scores.map(&:box).last
    if params[:chatroom]
      # [A] displays a chatroom after selecting a chatroom name from the chatrooms/show dropdown
      # [1..] removes the first character '#' of the name (same as [1..-1])
      @chatroom = Chatroom.find_by(name: params[:chatroom][1..])
      @box_nb = @chatroom&.box&.box_number
      # general chatroom has no round, then set @round to club's current round
      # @round = @chatroom.box.round
      #  @round = @chatroom.box.round unless @chatroom.name == "general"
      #  @round_nb = round_label(@round)
      #end
    elsif (params[:round] && current_user.role == "player") || params[:box]
      # [B] displays a chatroom after selecting a club, a round and a box number
      # either selects an open chatroom or create (open) a chatroom
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
        @chatroom.update(box: @box)

        # Broadcast notification to all users with access
        @chatroom.users_with_access.each do |user|
          notification_data = {
            type: "new_chatroom",
            chatroom_id: @chatroom.id,
            chatroom_name: @chatroom.name
          }

          ActionCable.server.broadcast(
            "notifications_#{user.id}",
            notification_data.to_json
          )
        end
      end
      #@box_nb = @chatroom.box.box_number
      #@round = @chatroom.box.round
      #@round_nb = round_label(@round)
    elsif params[:id]
      if params[:id] == "0"
        # [C] comming from the navbar dropdown: chose a chatroom from the dropdown lists
        # two forms :
        #   - a dropdown list of available chatrooms
        #   - a nested form of club/round/box numbers
        # display unread allowed chatrooms for admin/referee
        if ["admin", "referee", "player referee"].include?(current_user.role)
          @unread_chatrooms = current_user.unread_chatrooms
        end
        # [a] define list of available chatrooms in the first form
        if current_user == @admin
          # admin can access all existing chatrooms (including the #general chatroom)
          @chatrooms = Chatroom.all
        # elsif current_user.role == "referee" || current_user.role == "player referee"
        elsif REFEREE.include?(current_user.role)
          # referees have access to all chatrooms from their club + the #general chatroom
          # (skip chatrooms with no box, e.g. orphan or mislinked rows — #general is appended below)
          @chatrooms = Chatroom.all.select do |chatroom|
            chatroom.box&.round&.club == current_user.club
          end
          @chatrooms.push(@general_chatroom) unless @chatrooms.include?(@general_chatroom)
        else
          # player can only access chatrooms from their current or previous boxes
          @chatrooms = Chatroom.all.select do |chatroom|
            chatroom.box && my_box?(chatroom.box)
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
        # [D] comming from my_scores view (players) or unread chatroom links (admin/referee): display the box chatroom
        @chatroom = Chatroom.find(params[:id])
        unless @chatroom.users_with_access.include?(current_user)
          # chatroom not available to current user
          flash[:notice] = t('.no_access_flash')
          redirect_back(fallback_location: current_user.role == "player" ? my_scores_path(0) : root_path)
        end
        @box_nb = @chatroom.box.box_number if @chatroom.box
      end
    else
      # chatroom Id does not exist (bad url)
      flash[:notice] = t('.no_chatroom_flash')
      redirect_back(fallback_location: current_user.role == "player" ? my_scores_path(0) : root_path)
    end
    # instantiate @message for the new message form
    @message = Message.new

    # Mark chatroom as read for current user (when displaying a chatroom).
    # Note: when opening from the dropdown, the URL can be `chatrooms/0?chatroom=...`,
    # so `params[:id] == "0"` while `@chatroom` is present.
    if @chatroom
      mark_chatroom_as_read(@chatroom) if params[:id] != "0"
      set_adjacent_chatrooms if current_user == @admin || REFEREE.include?(current_user.role)
    end
  end

  # Delete a chatroom (admin only)
  # Prevents deletion of the general chatroom
  # Reassigns associated box to general chatroom if chatroom has a box
  def destroy
    # Authorization check: only admin can delete chatrooms
    unless current_user == @admin
      flash[:alert] = t('chatrooms.show.unauthorized')
      redirect_back(fallback_location: root_path)
      return
    end

    @chatroom = Chatroom.find(params[:id])
    chatroom_name = @chatroom.name
    messages_count = @chatroom.messages.count

    # Prevent deletion of the general chatroom (protected chatroom)
    if @chatroom.name == "general"
      flash[:alert] = t('chatrooms.show.cannot_delete_general')
      redirect_to chatroom_path(0)
      return
    end

    # If there's an associated box, detach it from this chatroom.
    # The box chatroom can be recreated lazily on next access.
    if @chatroom.box
      @chatroom.update(box: nil)
    end

    # Delete all messages first (they will be deleted automatically via dependent: :destroy)
    # Then delete the chatroom
    @chatroom.destroy

    flash[:notice] = t('chatrooms.show.chatroom_deleted', chatroom: chatroom_name, count: messages_count)
    redirect_to chatroom_path(0)
  end

  private

  # Mark chatroom as read for current user
  # Updates or creates ChatroomRead record with current timestamp
  def mark_chatroom_as_read(chatroom)
    ChatroomRead.find_or_create_by(user: current_user, chatroom: chatroom).update(last_read_at: Time.current)
  end

  # For admin/referees: previous/next navigation among open chatrooms available to the current user.
  # Sorted by chatroom name for deterministic ordering.
  def set_adjacent_chatrooms
    return unless @chatroom

    skip_empty_chatrooms = ActiveModel::Type::Boolean.new.cast(params[:skip_empty_chatrooms])

    available = if current_user == @admin
                  Chatroom.order(:name).to_a
                elsif REFEREE.include?(current_user.role)
                  club_chatrooms = Chatroom.all.select do |chatroom|
                    chatroom.box&.round&.club == current_user.club
                  end
                  (club_chatrooms + [@general_chatroom]).compact.uniq.sort_by(&:name)
                else
                  []
                end

    return if available.empty?

    if skip_empty_chatrooms
      available_ids = available.map(&:id)
      non_empty_ids = Message.where(chatroom_id: available_ids).distinct.pluck(:chatroom_id)
      # Keep the current chatroom in the list even if it's empty, so the UI can
      # still show prev/next navigation and let you move away.
      available = available.select { |c| non_empty_ids.include?(c.id) || c.id == @chatroom.id }
    end

    return if available.empty?

    idx = available.index { |c| c.id == @chatroom.id }
    return unless idx

    @previous_chatroom = (idx > 0 ? available[idx - 1] : nil)
    @next_chatroom = (idx < available.size - 1 ? available[idx + 1] : nil)
  end

  # Display form for new chatroom (unused - chatrooms created automatically)
  def new
    @chatroom = Chatroom.new
  end

  # Create new chatroom (unused - chatrooms created automatically in #show)
  def create
    @chatroom = Chatroom.new(params[:box_id])
    redirect_to chatroom_path(@chatroom)
  end
end
