class PreferencesController < ApplicationController
  def new
    #My details form for new user
    @preference = Preference.new(user_id: current_user.id)
  end

  def edit
    #My details form for existing user
    @preference = current_user.preference
  end

  def create
    # create preference record for current_user
    preference = Preference.new(clear_format: params[:clear_format]=="1", user_id: current_user.id)
    preference.save

    # update current_user details
    user_params = {
      nickname: params[:preference][:nickname],
      phone_number: params[:preference][:phone_number],
      email: params[:preference][:e_mail]
    }

    # Handle profile picture upload if present
    if params[:user] && params[:user][:profile_picture].present?
      user_params[:profile_picture] = params[:user][:profile_picture]
    end

    current_user.update(user_params)

    flash[:notice] = t(".details_stored_flash")

    redirect_to params[:password] == "1" ? edit_user_registration_path : boxes_path
  end

  def update
    # update preference record for current_user, coming form form preferences/edit.html.erb
    preference = Preference.find(params[:id])
    preference.update(clear_format: params[:clear_format]=="1")
    preference.save

    # update current_user details
    user_params = {
      nickname: params[:preference][:nickname],
      phone_number: params[:preference][:phone_number],
      email: params[:preference][:e_mail]
    }

    # Handle profile picture upload if present
    if params[:user] && params[:user][:profile_picture].present?
      user_params[:profile_picture] = params[:user][:profile_picture]
    end

    current_user.update(user_params)

    flash[:notice] = t(".details_stored_flash")
    redirect_to params[:password] == "1" ? edit_user_registration_path : boxes_path
  end

#  private

#  def preference_params
#    params.require(:preference).permit(:photo, :clear_format)
#  end
end
