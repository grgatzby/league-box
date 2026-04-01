class AddBoxReferenceToChatrooms < ActiveRecord::Migration[7.0]
  def up
    add_reference :chatrooms, :box, foreign_key: true, null: true
    add_index :chatrooms, :box_id, unique: true, where: "box_id IS NOT NULL", name: "index_chatrooms_on_box_id_unique"

    # Backfill from legacy boxes.chatroom_id ownership.
    # Keep the shared "general" chatroom detached (box_id = nil).
    execute <<~SQL.squish
      WITH candidates AS (
        SELECT b.chatroom_id, MIN(b.id) AS box_id
        FROM boxes b
        JOIN chatrooms c ON c.id = b.chatroom_id
        WHERE c.name <> 'general'
        GROUP BY b.chatroom_id
      )
      UPDATE chatrooms c
      SET box_id = candidates.box_id
      FROM candidates
      WHERE c.id = candidates.chatroom_id
    SQL
  end

  def down
    remove_index :chatrooms, name: "index_chatrooms_on_box_id_unique"
    remove_reference :chatrooms, :box, foreign_key: true
  end
end
