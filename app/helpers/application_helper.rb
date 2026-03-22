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
end
