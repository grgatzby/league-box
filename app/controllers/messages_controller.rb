class MessagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:contact]
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

  def contact
    sign_in(@dummy_user)
    @chatroom = @contact_chatroom
    @message = Message.new
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
