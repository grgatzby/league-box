class TournamentContextResolver
  def initialize(user)
    @user = user
  end

  def contexts(include_inactive_latest: false)
    return [] unless @user

    active_contexts = (singles_contexts(active_only: true) + doubles_contexts(active_only: true) + referee_contexts(active_only: true))
                      .uniq { |ctx| [ctx[:round_id], ctx[:format]] }
    return active_contexts unless include_inactive_latest

    formats_with_active_context = active_contexts.map { |ctx| ctx[:format] }.uniq
    fallback_contexts = latest_context_per_missing_format(formats_with_active_context)

    (active_contexts + fallback_contexts).uniq { |ctx| [ctx[:round_id], ctx[:format]] }
  end

  private

  def singles_contexts(active_only:)
    @user.user_box_scores.includes(box: :round).map(&:box).map(&:round).uniq.filter_map do |round|
      next unless round
      next if active_only && !active_round?(round)
      next unless round.tournament_format == "singles_tennis"

      build_context(round, :singles)
    end
  end

  def doubles_contexts(active_only:)
    @user.teams.includes(:round).uniq.filter_map do |team|
      round = team.round
      next unless round
      next if active_only && !active_round?(round)
      next unless round.doubles_format?

      build_context(round, :doubles)
    end.uniq { |ctx| [ctx[:round_id], ctx[:format]] }
  end

  def latest_context_per_missing_format(formats_with_active_context)
    joined_rounds = (
      @user.user_box_scores.includes(box: :round).map(&:box).map(&:round) +
      @user.teams.includes(:round).map(&:round) +
      referee_rounds
    ).compact.uniq

    joined_rounds
      .group_by(&:tournament_format)
      .reject { |format, _| formats_with_active_context.include?(format) }
      .values
      .filter_map do |rounds|
        round = rounds.max_by { |r| [r.end_date || Date.new(1900, 1, 1), r.start_date || Date.new(1900, 1, 1), r.id] }
        next unless round

        mode = round.doubles_format? ? :doubles : :singles
        build_context(round, mode)
      end
  end

  def active_round?(round)
    round.start_date <= Date.today && round.end_date >= Date.today
  end

  def referee_contexts(active_only:)
    return [] unless referee_like_user?

    referee_rounds.filter_map do |round|
      next unless round
      next if active_only && !active_round?(round)

      mode = round.doubles_format? ? :doubles : :singles
      build_context(round, mode)
    end
  end

  def referee_rounds
    return [] unless referee_like_user?
    return [] unless @user.club_id

    Round.where(club_id: @user.club_id).to_a
  end

  def referee_like_user?
    @user.role.to_s.include?("referee")
  end

  def build_context(round, mode)
    {
      round_id: round.id,
      club_id: round.club_id,
      format: round.tournament_format,
      mode: mode,
      title: title_for(round)
    }
  end

  def title_for(round)
    format_label = case round.tournament_format
                   when "singles_tennis"
                     "Singles Tennis"
                   when "doubles_tennis"
                     "Doubles Tennis"
                   when "doubles_padel"
                     "Doubles Padel"
                   else
                     round.tournament_format.to_s.humanize
                   end

    "#{round.club.name} - #{format_label} - #{round_label(round)}"
  end

  def round_label(round)
    league_start = round.league_start
    rounds_ordered = Round.where(league_start:, club_id: round.club_id)
                          .order("start_date ASC")
                          .map(&:id)
    "#{I18n.l(league_start, format: :yyymm_date)}_R#{format('%02d', rounds_ordered.index(round.id) + 1)}"
  end
end
