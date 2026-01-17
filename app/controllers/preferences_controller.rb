# Preferences Controller
# Handles user preference management, including personal details and club website updates.
# Allows users to update their profile information (nickname, name, email, phone, profile picture).
# Allows admin and referees to update club website information.
class PreferencesController < ApplicationController
  # Display form for existing user to edit preferences
  # Creates preference record if it doesn't exist, then shows the form
  # Shows current user's preferences including personal details and club website (for admin/referee)
  def edit
    # Handle case where ID is 0 (from navbar when preference doesn't exist yet) or preference is nil
    if params[:id] == "0" || current_user.preference.nil?
      @preference = current_user.preference || Preference.create(user_id: current_user.id, clear_format: false)
    else
      @preference = Preference.find(params[:id])
      # Ensure the preference belongs to the current user
      unless @preference.user_id == current_user.id
        @preference = current_user.preference || Preference.create(user_id: current_user.id, clear_format: false)
      end
    end
  end

  
  # Update preference record and user/club details for existing user
  # Tracks changes to only show flash notice if actual changes were made
  # Handles user details, profile picture, and club website updates (for admin/referee)
  def update
    # Track if any changes were made (only show flash notice if changes occurred)
    changes_made = false

    # update preference record for current_user, coming form form preferences/edit.html.erb
    preference = Preference.find(params[:id])
    new_clear_format = params[:clear_format] == "1"
    if preference.clear_format != new_clear_format
      preference.update(clear_format: new_clear_format)
      preference.save
      changes_made = true
    end

    # Check if user details changed (using strong parameters)
    pref_params = preference_params
    user_params = {}
    user_params[:nickname] = pref_params[:nickname] if pref_params[:nickname].to_s != (current_user.nickname || "").to_s
    user_params[:first_name] = pref_params[:first_name] if pref_params[:first_name].to_s != (current_user.first_name || "").to_s
    user_params[:last_name] = pref_params[:last_name] if pref_params[:last_name].to_s != (current_user.last_name || "").to_s
    user_params[:phone_number] = pref_params[:phone_number] if pref_params[:phone_number].to_s != (current_user.phone_number || "").to_s
    user_params[:email] = pref_params[:e_mail] if pref_params[:e_mail].to_s != (current_user.email || "").to_s

    # Handle profile picture upload if present
    if params[:user] && params[:user][:profile_picture].present?
      user_params[:profile_picture] = params[:user][:profile_picture]
      changes_made = true
    end

    if user_params.any?
      current_user.update(user_params)
      changes_made = true
    end

    # update club website (if user is admin or referee)
    if current_user && (current_user.role&.include?("referee") || current_user == @admin)
      begin
        # Determine which club to update
        club = if current_user == @admin && params[:club_id].present?
                 # Admin can update any club
                 Club.find(params[:club_id])
               else
                 # Referee/player can only update their own club
                 current_user.club
               end

        # Check if website changed (using strong parameters)
        website_value = preference_params[:website] || ""
        if (club.website || "").to_s != website_value.to_s
          club.update(website: website_value)
          changes_made = true
        end
      rescue ActiveRecord::RecordNotFound => e
        # Club not found - log error but don't break the form submission
        Rails.logger.error("Club not found in preferences update: #{e.message}")
      rescue => e
        # Log any other errors but don't break the form submission
        Rails.logger.error("Error updating club website in preferences: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end

    # Only show flash notice if changes were made
    flash[:notice] = t(".details_stored_flash") if changes_made
    redirect_to params[:password] == "1" ? edit_user_registration_path : boxes_path
  end

  private

  # Strong parameters for preference form
  # Permits website field even though it's not a Preference attribute
  # The website field is used to update the Club model, not the Preference model
  def preference_params
    params.require(:preference).permit(:nickname, :first_name, :last_name, :phone_number, :e_mail, :website)
  end
end
