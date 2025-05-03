class PreferencesController < ApplicationController
  def new
    #on 10/02/2025 replaced pages#my_details with preferences#new and preferences#edit
    @preference = Preference.new(user_id: current_user.id)
  end

  def create
    # create preference record for current_user
    #preference = Preference.new(clear_format: params[:clear_format]=="1", user_id: current_user.id)

    preference = Preference.new
    preference.user_id = current_user.id
    preference.clear_format = params[:clear_format]=="1"
    preference.update(photo: preference_params[:photo])
    preference.save
    # update current_user details
    current_user.update(nickname: params[:preference][:nickname],
    phone_number: params[:preference][:phone_number],
    email: params[:preference][:e_mail])

    flash[:notice] = t(".details_stored_flash")

    redirect_to params[:password] == "1" ? edit_user_registration_path : boxes_path
  end

  def edit
    #on 10/02/2025 replaced pages#my_details with preferences#new and preferences#edit
    @preference = current_user.preference
  end

  def update
    # update preference record for current_user, coming form form my_details.html.erb
    preference = Preference.find(params[:id])
    preference.update(preference_params)
    preference.update(clear_format: params[:clear_format]=="1")
    #image = params[:preference][:photo]
    #preference.photo.attach(io: image,
    #        filename: image.original_filename,
    #        content_type: image.content_type)
    #preference.clear_format = params[:clear_format]=="1"
    preference.save
    # update current_user details
    current_user.update(nickname: params[:preference][:nickname],
                        phone_number: params[:preference][:phone_number],
                        email: params[:preference][:e_mail])

    flash[:notice] = t(".details_stored_flash")
    redirect_to params[:password] == "1" ? edit_user_registration_path : boxes_path
  end

  private

  def preference_params
    params.require(:preference).permit(:photo, :clear_format)
    # params.permit!
  end
end
