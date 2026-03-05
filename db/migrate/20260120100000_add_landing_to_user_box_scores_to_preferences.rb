class AddLandingToUserBoxScoresToPreferences < ActiveRecord::Migration[7.0]
  def change
    add_column :preferences, :landing_to_user_box_scores, :boolean, default: false, null: false
  end
end
