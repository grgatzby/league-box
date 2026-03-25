# frozen_string_literal: true

namespace :data_fixes do
  desc <<-DESC.squish
    Rename box chatroom names to match Box#chatroom_label (Round#round_label with S/D/P).
    Two-phase update avoids uniqueness conflicts when names were swapped.
    Set DRY_RUN=1 to print planned renames only.
  DESC
  task rename_chatroom_names_from_boxes: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil))
    I18n.locale = I18n.default_locale

    to_fix = []
    skipped_blank = []

    Box.includes(:chatroom, round: :club).find_each do |box|
      next unless box.round&.club && box.chatroom

      expected = box.chatroom_label
      if expected.blank?
        skipped_blank << { box_id: box.id, round_id: box.round_id, chatroom_id: box.chatroom_id }
        next
      end

      next if box.chatroom.name == expected

      to_fix << {
        chatroom: box.chatroom,
        box_id: box.id,
        from: box.chatroom.name,
        to: expected
      }
    end

    duplicates = to_fix.group_by { |h| h[:to] }.select { |_, rows| rows.size > 1 }
    if duplicates.any?
      puts "ERROR: multiple boxes want the same chatroom name — aborting."
      duplicates.each do |name, rows|
        puts "  #{name.inspect}: box_ids #{rows.map { |r| r[:box_id] }.inspect}"
      end
      exit 1
    end

    if skipped_blank.any?
      puts "WARNING: #{skipped_blank.size} box(es) skipped (empty round label — check league_start / round data):"
      skipped_blank.first(10).each { |s| puts "  #{s.inspect}" }
      puts "  ..." if skipped_blank.size > 10
    end

    if to_fix.empty?
      puts "Nothing to rename — all box chatrooms already match Box#chatroom_label."
    else
      puts(dry_run ? "DRY RUN — would rename #{to_fix.size} chatroom(s):" : "Renaming #{to_fix.size} chatroom(s):")
      to_fix.each do |h|
        puts "  chatroom #{h[:chatroom].id} (box #{h[:box_id]}): #{h[:from].inspect} => #{h[:to].inspect}"
      end

      unless dry_run
        Chatroom.transaction do
          to_fix.each do |h|
            h[:chatroom].update!(name: "__tmp_rename_#{h[:chatroom].id}_#{SecureRandom.hex(4)}")
          end
          to_fix.each do |h|
            h[:chatroom].update!(name: h[:to])
          end
        end
        puts "Done."
      end
    end
  end
end
