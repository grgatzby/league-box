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
