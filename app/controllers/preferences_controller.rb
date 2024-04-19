class PreferencesController < ApplicationController
  def create
    # create preference record for current_user
    preference = Preference.new(clear_format: params[:clear_format]=="1", user_id: current_user.id)
    preference.save
    # update current_user details
    current_user.update(nickname: params[:preference][:nickname],
                        phone_number: params[:preference][:phone_number],
                        email: params[:preference][:e_mail])

    flash[:notice] = t(".details_stored_flash")

    redirect_to params[:password] == "1" ? edit_user_registration_path : boxes_path
  end

  def update
    # update preference record for current_user
    preference = Preference.find(params[:id])
    preference.update(clear_format: params[:clear_format]=="1")
    preference.save
    # update current_user details
    current_user.update(nickname: params[:preference][:nickname],
                        phone_number: params[:preference][:phone_number],
                        email: params[:preference][:e_mail])

    flash[:notice] = t(".details_stored_flash")
    redirect_to params[:password] == "1" ? edit_user_registration_path : boxes_path
  end
end
