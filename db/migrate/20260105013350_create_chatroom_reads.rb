class CreateChatroomReads < ActiveRecord::Migration[7.0]
  def change
    create_table :chatroom_reads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :chatroom, null: false, foreign_key: true
      t.datetime :last_read_at

      t.timestamps
    end

    add_index :chatroom_reads, [:user_id, :chatroom_id], unique: true
  end
end
