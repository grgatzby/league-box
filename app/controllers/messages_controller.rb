class MessagesController < ApplicationController
  before_action :set_message, only: [:destroy]
  before_action :authorize_admin, only: [:destroy]

  def create
    @chatroom = Chatroom.find(params[:chatroom_id])
    @message = Message.new(message_params)
    @message.chatroom = @chatroom
    @message.user = current_user
    if @message.save
      # redirect_to chatroom_path(@chatroom)
      ChatroomChannel.broadcast_to(
        @chatroom,
        render_to_string(partial: "message", locals: { message: @message })
      )

      # Broadcast notifications to all users with access
      @chatroom.users_with_access.each do |user|
        if user == current_user
          # Mark this message as read since they sent it
          ChatroomRead.find_or_create_by(user: current_user, chatroom: @chatroom).update(last_read_at: Time.current)
        else
          # Notify other users
          notification_data = {
            type: "new_message",
            chatroom_id: @chatroom.id,
            chatroom_name: @chatroom.name,
            message_id: @message.id
          }

          ActionCable.server.broadcast(
            "notifications_#{user.id}",
            notification_data.to_json
          )
        end
      end

      head :ok
    else
      render "chatrooms/show", status: :unprocessable_entity
    end
  end

  def destroy
    @chatroom = @message.chatroom
    @message.destroy
    # Broadcast deletion to all subscribers
    ChatroomChannel.broadcast_to(
      @chatroom,
      { action: "delete", message_id: @message.id }.to_json
    )
    head :ok
  end

  def bulk_delete
    authorize_admin
    @chatroom = Chatroom.find(params[:chatroom_id])
    message_ids = params[:message_ids] || []

    if message_ids.any?
      messages = @chatroom.messages.where(id: message_ids)
      deleted_ids = messages.pluck(:id)
      messages.destroy_all

      # Broadcast deletion for each message
      deleted_ids.each do |message_id|
        ChatroomChannel.broadcast_to(
          @chatroom,
          { action: "delete", message_id: message_id }.to_json
        )
      end

      redirect_to chatroom_path(@chatroom), notice: t('chatrooms.show.bulk_delete_success', count: deleted_ids.count)
    else
      redirect_to chatroom_path(@chatroom), alert: t('chatrooms.show.no_messages_selected')
    end
  end

  private

  def set_message
    @message = Message.find(params[:id])
  end

  def authorize_admin
    unless current_user == @admin
      head :forbidden
    end
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
