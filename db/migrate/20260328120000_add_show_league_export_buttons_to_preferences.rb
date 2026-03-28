class AddShowLeagueExportButtonsToPreferences < ActiveRecord::Migration[7.0]
  def change
    add_column :preferences, :show_league_export_buttons, :boolean, default: true, null: false
  end
end
