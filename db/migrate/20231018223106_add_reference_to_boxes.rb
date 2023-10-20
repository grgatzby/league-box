class AddReferenceToBoxes < ActiveRecord::Migration[7.0]
  # thanks to Mattia Orfano
  # https://dev.to/mattiaorfano/rails-addreference-with-null-constraint-on-existing-table-4n6n
  def change
    default_chatroom_id = Chatroom.first.try(:id) || Chatroom.create(name: 'general').id
    add_reference :boxes, :chatroom, null: false, default: default_chatroom_id, foreign_key: true

    # set default back to nil
    change_column_default :boxes, :chatroom_id, nil
  end
end
