class ContactsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[new create sent]

  def new
    @contact = Contact.new
    if current_user == @admin
      @referees = User.where(role: "referee")
    end
  end

  def create
    # The "contact us" feature was previously using a chatroom;
    # now it generates an email to admin with multiple file attachments thanks to this post
    # https://stackoverflow.com/questions/72229213/rails-mail-form-cant-send-attachment
    # an the following fix:
    # heartcombo/mail_form#76
    @contact = Contact.new(contact_params)
    @contact.request = request
    if @contact.deliver
      # used to check parameters from invoking view link:
      # redirect_to contacts_sent_path(request.parameters)
      redirect_to contacts_sent_path(round_id: params[:contact][:round_id])
    else
      flash.now[:error] = t('.error_flash')
      render :new, status: :unprocessable_entity
    end
  end

  def sent
    if params[:round_id]
      # if processing a new round request (from Referee view page), params[:round_id] is defined
      @round = Round.find(params[:round_id])
      @club_name = @round.club.name
    end
  end

  private

  def contact_params
    # Strong params; formely:
    # params.require(:contact).permit(:subject, :name, :email, :phone, :message, :formcheck, :files => [])
    # replaced ':files => []' with ':files, files: []' to allow single file attachment (for a new round request)
    # and multi file attachment (contact us form) as both use the same form
    params.require(:contact).permit(:subject, :name, :email, :phone, :message, :formcheck, :files, files: [])
  end
end
