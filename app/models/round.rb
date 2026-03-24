class Round < ApplicationRecord
  TOURNAMENT_FORMATS = %w[singles_tennis doubles_tennis doubles_padel].freeze

  # Suffix on round labels: singles tennis / doubles tennis / padel
  TOURNAMENT_FORMAT_LABEL_SUFFIX = {
    "singles_tennis" => "S",
    "doubles_tennis" => "D",
    "doubles_padel" => "P"
  }.freeze

  scope :current, ->(today = Date.today) { where("start_date <= ? AND end_date >= ?", today, today) }
  belongs_to :club
  has_many :boxes, dependent: :destroy
  has_many :user_box_scores, through: :boxes
  has_many :teams, dependent: :destroy

  # the rounds/new.html.erb form accepts nested attributes for boxes and user_box_scores
  accepts_nested_attributes_for :boxes

  validates :tiebreak_points, numericality: { greater_than_or_equal_to: 7 }, allow_nil: true
  validates :tournament_format, inclusion: { in: TOURNAMENT_FORMATS }

  # Returns the effective tiebreak points for this round
  # If tiebreak_points is set on the round, use it; otherwise inherit from club
  def effective_tiebreak_points
    tiebreak_points || club.tiebreak_points
  end

  def doubles_format?
    %w[doubles_tennis doubles_padel].include?(tournament_format)
  end

  # Single source of truth for round labels (see also ApplicationController#round_label, TournamentContextResolver#title_for).
  # Format: yyyy/mm_RnnS — league start date, round order within that league+club, then S/D/P.
  def round_label
    part = round_label_round_part
    return "" if part.blank?

    "#{I18n.l(league_start, format: :yyymm_date)}_#{part}"
  end

  # Compact segment only, e.g. "R01S" (for lists where the yyyy/mm prefix is shown elsewhere).
  def round_label_round_part
    n = round_number_in_league
    return nil if n.nil?

    "R#{format('%02d', n)}#{tournament_format_suffix}"
  end

  def tournament_format_suffix
    TOURNAMENT_FORMAT_LABEL_SUFFIX[tournament_format] || "?"
  end

  # 1-based index among rounds sharing this club and league_start, ordered by start_date.
  def round_number_in_league
    return nil unless league_start && id

    ids = Round.where(league_start:, club_id: club_id).order(:start_date).map(&:id)
    idx = ids.index(id)
    idx ? idx + 1 : nil
  end
end
