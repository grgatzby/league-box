class RemoveChatroomReferenceFromBoxes < ActiveRecord::Migration[7.0]
  def up
    if foreign_key_exists?(:boxes, :chatrooms)
      remove_foreign_key :boxes, :chatrooms
    end
    if index_exists?(:boxes, :chatroom_id, name: "index_boxes_on_chatroom_id")
      remove_index :boxes, name: "index_boxes_on_chatroom_id"
    end
    remove_column :boxes, :chatroom_id if column_exists?(:boxes, :chatroom_id)
  end

  def down
    add_reference :boxes, :chatroom, foreign_key: true, null: true

    # Backfill from the new ownership direction (chatrooms.box_id -> boxes.chatroom_id).
    execute <<~SQL.squish
      UPDATE boxes b
      SET chatroom_id = c.id
      FROM chatrooms c
      WHERE c.box_id = b.id
    SQL
  end
end
