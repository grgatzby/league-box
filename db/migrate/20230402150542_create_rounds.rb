class CreateRounds < ActiveRecord::Migration[7.0]
  def change
    create_table :rounds do |t|
      t.date :start_date
      t.date :end_date
      t.references :club, null: false, foreign_key: true

      t.timestamps
    end
  end
end
