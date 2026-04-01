# frozen_string_literal: true

namespace :data_fixes do
  desc <<-DESC.squish
    Rename box chatroom names to match Box#chatroom_label (Round#round_label with S/D/P).
    Two-phase update avoids uniqueness conflicts when names were swapped.
    Set DRY_RUN=1 to print planned changes only.
    If some chatrooms are shared by multiple boxes, set SPLIT_SHARED=1 to split them.
  DESC
  task rename_chatroom_names_from_boxes: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil))
    split_shared = ActiveModel::Type::Boolean.new.cast(ENV.fetch("SPLIT_SHARED", nil))
    I18n.locale = I18n.default_locale

    planned_by_box = []
    skipped_blank = []

    Box.includes(:chatroom, round: :club).find_each do |box|
      next unless box.round&.club && box.chatroom

      expected = box.chatroom_label
      if expected.blank?
        skipped_blank << { box_id: box.id, round_id: box.round_id, chatroom_id: box.chatroom&.id }
        next
      end

      planned_by_box << {
        chatroom: box.chatroom,
        box_id: box.id,
        from: box.chatroom.name,
        to: expected
      }
    end

    shared_groups = planned_by_box.group_by { |h| h[:chatroom].id }.select { |_, rows| rows.size > 1 }
    if shared_groups.any? && !split_shared
      puts "ERROR: detected #{shared_groups.size} shared chatroom(s) linked to multiple boxes."
      puts "This is why you saw repeated rows like `chatroom 3 (...)`."
      shared_groups.first(20).each do |chatroom_id, rows|
        puts "  chatroom #{chatroom_id} is linked to box_ids #{rows.map { |r| r[:box_id] }.sort.inspect}"
      end
      puts "  ..." if shared_groups.size > 20
      puts "Re-run with SPLIT_SHARED=1 to split shared chatrooms before renaming."
      exit 1
    end

    rename_targets = {}
    relink_targets = []

    planned_by_box.group_by { |h| h[:chatroom].id }.each_value do |rows|
      rows = rows.sort_by { |r| r[:box_id] }
      if rows.size == 1
        row = rows.first
        next if row[:from] == row[:to]
        rename_targets[row[:chatroom].id] = {
          chatroom: row[:chatroom],
          from: row[:from],
          to: row[:to],
          box_id: row[:box_id]
        }
      else
        keeper = rows.first
        rename_targets[keeper[:chatroom].id] = {
          chatroom: keeper[:chatroom],
          from: keeper[:from],
          to: keeper[:to],
          box_id: keeper[:box_id]
        }
        rows.drop(1).each do |row|
          relink_targets << row
        end
      end
    end

    desired_names = rename_targets.values.map { |r| r[:to] } + relink_targets.map { |r| r[:to] }
    duplicates = desired_names.group_by(&:itself).select { |_, rows| rows.size > 1 }
    if duplicates.any?
      puts "ERROR: multiple boxes want the same chatroom name — aborting."
      duplicates.each_key do |name|
        box_ids = planned_by_box.select { |h| h[:to] == name }.map { |h| h[:box_id] }
        puts "  #{name.inspect}: box_ids #{box_ids.inspect}"
      end
      exit 1
    end

    rename_ids = rename_targets.keys
    already_taken = Chatroom.where(name: desired_names.uniq).where.not(id: rename_ids)
    if already_taken.exists?
      puts "ERROR: some target names are already used by unaffected chatrooms:"
      already_taken.limit(20).pluck(:id, :name).each do |id, name|
        puts "  chatroom #{id}: #{name.inspect}"
      end
      puts "  ..." if already_taken.count > 20
      exit 1
    end

    if skipped_blank.any?
      puts "WARNING: #{skipped_blank.size} box(es) skipped (empty round label — check league_start / round data):"
      skipped_blank.first(10).each { |s| puts "  #{s.inspect}" }
      puts "  ..." if skipped_blank.size > 10
    end

    if rename_targets.empty? && relink_targets.empty?
      puts "Nothing to rename — all box chatrooms already match Box#chatroom_label and are not shared."
    else
      puts(
        dry_run ?
        "DRY RUN — #{rename_targets.size} rename(s), #{relink_targets.size} relink(s):" :
        "Applying #{rename_targets.size} rename(s), #{relink_targets.size} relink(s):"
      )
      rename_targets.values.sort_by { |h| [h[:chatroom].id, h[:box_id]] }.each do |h|
        puts "  rename chatroom #{h[:chatroom].id} (box #{h[:box_id]}): #{h[:from].inspect} => #{h[:to].inspect}"
      end
      relink_targets.sort_by { |h| h[:box_id] }.each do |h|
        puts "  relink box #{h[:box_id]} from chatroom #{h[:chatroom].id} to NEW chatroom named #{h[:to].inspect}"
      end

      unless dry_run
        Chatroom.transaction do
          rename_targets.values.each do |h|
            h[:chatroom].update!(name: "__tmp_rename_#{h[:chatroom].id}_#{SecureRandom.hex(4)}")
          end

          created_chatrooms = []
          relink_targets.each do |h|
            tmp = Chatroom.create!(name: "__tmp_new_for_box_#{h[:box_id]}_#{SecureRandom.hex(4)}")
            tmp.update!(box_id: h[:box_id])
            created_chatrooms << { chatroom: tmp, to: h[:to], box_id: h[:box_id] }
          end

          rename_targets.values.each do |h|
            h[:chatroom].update!(name: h[:to])
          end
          created_chatrooms.each do |h|
            h[:chatroom].update!(name: h[:to])
          end
        end
        puts "Done."
      end
    end
  end
end
