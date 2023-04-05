class CreateBoxes < ActiveRecord::Migration[7.0]
  def change
    create_table :boxes do |t|
      t.integer :box_number
      t.references :round, null: false, foreign_key: true

      t.timestamps
    end
  end
end
