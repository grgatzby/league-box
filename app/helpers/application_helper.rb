module ApplicationHelper
  # Merge into path helpers when a tournament format context is active (singles / doubles / padel).
  def tournament_format_params
    return {} unless @tournament_format_for_links.present?

    { tournament_format: @tournament_format_for_links }
  end

  # Safe date for matches/new after redirect_with_params (invalid score, etc.).
  # Avoids Date.strptime raising on blank, malformed, or non-ISO query values.
  def match_form_date_value(raw, fallback_date)
    return fallback_date if raw.blank?

    if raw.is_a?(Hash) || (defined?(ActionController::Parameters) && raw.is_a?(ActionController::Parameters))
      h = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h.stringify_keys : raw.stringify_keys
      y = h["1"] || h["1i"]
      m = h["2"] || h["2i"]
      d = h["3"] || h["3i"]
      return fallback_date unless y.present? && m.present? && d.present?

      return Date.new(y.to_i, m.to_i, d.to_i)
    end

    str = raw.to_s.strip
    return fallback_date unless str.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Date.strptime(str, "%Y-%m-%d")
  rescue ArgumentError, TypeError, Date::Error
    fallback_date
  end

  def profile_picture_circular_url(user, size = 50)
    return nil unless user.profile_picture.present?

    begin
      # Get the base URL from CarrierWave
      base_url = user.profile_picture.url.to_s

      # If it's already a Cloudinary URL, add transformations
      # Format: .../upload/TRANSFORMATIONS/public_id
      if base_url.include?('res.cloudinary.com')
        # Insert transformations before the public_id part
        # Transformations: c_thumb,g_face,w_SIZE,h_SIZE,r_max
        transformation = "c_thumb,g_face,w_#{size},h_#{size},r_max/"
        base_url.sub('/upload/', "/upload/#{transformation}")
      else
        base_url
      end
    rescue StandardError => e
      # Fallback to regular URL if transformation fails
      user.profile_picture.url.to_s
    end
  end

  def player_profile_picture_or_favicon(user, size = 30)
    if user.profile_picture.present?
      profile_picture_circular_url(user, size)
    elsif user.club&.logo.present?
      # Use club logo as fallback if available
      user.club.logo.url
    else
      image_path('favicon.png')
    end
  end

  # Grid match cells (doubles/padel): compact labels, e.g. "E. Jack. / N. Mard."
  # — initial of first name + first 4 letters of last name, trailing "." if last name is longer than 4 chars.
  def abbreviated_player_label(user)
    return "" unless user

    first = user.first_name.to_s.strip
    last = user.last_name.to_s.strip
    initial_segment = first.present? ? "#{first[0].upcase}." : "?."

    return initial_segment if last.blank?

    abbr = last.length > 4 ? last[0, 4] : last
    abbr = if abbr.length > 1
             abbr[0].upcase + abbr[1..].downcase
           else
             abbr.upcase
           end
    suffix = last.length > 4 ? "." : ""
    "#{initial_segment} #{abbr}#{suffix}".strip
  end

  # Same player order as Team#display_name (alphabetical by last name, then first name).
  def abbreviated_team_label(team)
    return team.display_name.to_s unless team.respond_to?(:users)

    players = team.users.compact.sort_by { |u| [u.last_name.to_s.strip.downcase, u.first_name.to_s.strip.downcase] }
    return team.display_name.to_s if players.empty?

    players.map { |u| abbreviated_player_label(u) }.join(" / ")
  end

  def team_label(team, current_user = nil)
    names = team.users.sort_by { |u| u.last_name.to_s }.map do |user|
      escaped_name = ERB::Util.h(user.last_name.to_s)
      if current_user && user.id == current_user.id
        "<span class=\"color-tennis-red\">#{escaped_name}</span>"
      else
        escaped_name
      end
    end

    if names.any?
      names.join(" / ").html_safe
    else
      ERB::Util.h(team.display_name.to_s)
    end
  end

  # Same semantics as ApplicationController#round_label (helper_method), callable from helpers without delegation.
  def format_round_label_for_popover(round)
    league_start = round.league_start
    rounds_ordered = Round.where(league_start:, club_id: round.club_id)
                          .order(:start_date)
                          .map(&:id)
    "#{l(league_start, format: :yyymm_date)}_R#{format('%02d', rounds_ordered.index(round.id) + 1)}"
  end

  # Round history for popovers: singles (UserBoxScore) + doubles/padel (TeamBoxScore), grouped by tournament format.
  # Optional club_id limits rows to that club’s rounds.
  def tournament_format_grouped_history_html(user, club_id: nil)
    return "".html_safe unless user

    ubs_list = user.user_box_scores.select do |ubs|
      ubs.box.round.tournament_format == "singles_tennis" && (club_id.nil? || ubs.box.round.club_id == club_id)
    end

    team_tbs = []
    user.teams.each do |team|
      team.team_box_scores.each do |tbs|
        rd = tbs.box.round
        next if club_id && rd.club_id != club_id
        next unless rd.doubles_format?

        team_tbs << tbs
      end
    end

    doubles_tennis = team_tbs.select { |tbs| tbs.box.round.tournament_format == "doubles_tennis" }
    padel = team_tbs.select { |tbs| tbs.box.round.tournament_format == "doubles_padel" }

    sections = %w[singles_tennis doubles_tennis doubles_padel].map do |tf|
      items = case tf
              when "singles_tennis" then ubs_list
              when "doubles_tennis" then doubles_tennis
              when "doubles_padel" then padel
              end
      [tf, items]
    end

    parts = []
    sections.each do |tf, items|
      next if items.blank?

      items = items.sort_by { |x| x.box.round.start_date }
      lines = items.reverse.map do |row|
        r = row.box.round
        "#{format_round_label_for_popover(r)} - Box#{format('%02d', row.box.box_number)}, ##{row.rank} <br />"
      end.join

      title = I18n.t("shared.player_history.format.#{tf}",
                     default: tournament_format_default_section_title(tf))
      parts << "<u>#{ERB::Util.h(title)}</u><br />#{lines}"
    end

    parts.join("<br />").html_safe
  end

  def tournament_format_default_section_title(tf)
    case tf.to_s
    when "singles_tennis" then "Singles tennis"
    when "doubles_tennis" then "Doubles tennis"
    when "doubles_padel" then "Padel"
    else tf.to_s.humanize
    end
  end

  # Full popover body: contact + format-grouped history (league table singles / doubles rows).
  def player_league_popover_html(player, club_id: nil)
    fn = ERB::Util.h("#{player.first_name} #{player.last_name}".strip)
    body = +"<b>#{fn}</b><br />📞 #{ERB::Util.h(player.phone_number.to_s)}<br />✉️ #{ERB::Util.h(player.email.to_s)}<br />"
    hist = tournament_format_grouped_history_html(player, club_id: club_id)
    body << hist.to_s if hist.present?
    body.html_safe
  end

  # Doubles/padel league row: each team member with contact + history, separated by a rule.
  def doubles_team_row_popover_html(team, club_id: nil)
    players = team.respond_to?(:sorted_players) ? team.sorted_players : team.users.to_a
    blocks = players.map { |member| player_league_popover_html(member, club_id: club_id) }
    safe_join(blocks, "<hr class=\"my-1\" />".html_safe)
  end

  # Player directory: history only (contact is already on the row).
  def player_directory_history_popover_html(user, club_id: nil)
    hist = tournament_format_grouped_history_html(user, club_id: club_id)
    if hist.present?
      hist
    else
      ERB::Util.h(I18n.t("shared.player_history.empty", default: "No ranking history in this club yet."))
    end
  end
end
