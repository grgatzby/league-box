class ContactsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :sent]

  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(contact_params)
    @contact.request = request
    if @contact.deliver
      redirect_to action: :sent
    else
      flash.now[:error] = 'Could not send message'
      render :new, status: :unprocessable_entity
    end
  end

  def sent
  end

  private

  def contact_params
    params.require(:contact).permit(:subject, :name, :email, :phone, :message, :nickname, :files => [])
  end
end
