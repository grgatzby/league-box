class ContactsController < ApplicationController
  # skip_before_action :authenticate_user!, only: [:new, :create, :sent]
  skip_before_action :authenticate_user!, only: %i[new create sent]

  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(contact_params)
    @contact.request = request
    if @contact.deliver
      # redirect_to contacts_sent_path(request.parameters)
      redirect_to contacts_sent_path(round_id: params[:contact][:round_id])
    else
      flash.now[:error] = t('.error_flash')
      render :new, status: :unprocessable_entity
    end
  end

  def sent
    # if processing a request new round (from Referee view page), then params[:round_id] is defined
    if params[:round_id]
      @round = Round.find(params[:round_id])
      @club_name = @round.club.name
    end
  end

  private

  def contact_params
    # params.require(:contact).permit(:subject, :name, :email, :phone, :message, :formcheck, :files => [])
    params.require(:contact).permit(:subject, :name, :email, :phone, :message, :formcheck, :files, files: [])
  end
end
