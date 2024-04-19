class PreferencesController < ApplicationController
  def create
    preference = Preference.new(clear_format: params[:clear_format]=="1", user_id: current_user.id)
    preference.save
    current_user.update(nickname: params[:preference][:nickname],
                        phone_number: params[:preference][:phone_number])

    flash[:notice] = t(".details_stored_flash")
    redirect_to boxes_path
  end

  def update
    preference = Preference.find(params[:id])
    preference.update(clear_format: params[:clear_format]=="1")
    preference.save
    current_user.update(nickname: params[:preference][:nickname],
                        phone_number: params[:preference][:phone_number])

    flash[:notice] = t(".details_stored_flash")
    redirect_to boxes_path
  end
end
