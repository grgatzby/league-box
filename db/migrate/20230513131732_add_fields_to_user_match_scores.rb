class AddFieldsToUserMatchScores < ActiveRecord::Migration[7.0]
  def change
    add_column :user_match_scores, :input_user_id, :integer
    add_column :user_match_scores, :input_date, :datetime
  end
end
