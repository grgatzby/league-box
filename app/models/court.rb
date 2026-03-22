class Court < ApplicationRecord
  COURT_KINDS = %w[tennis padel].freeze

  belongs_to :club
  has_many :matches, dependent: :destroy

  validates :court_kind, inclusion: { in: COURT_KINDS }

  # Tennis courts: singles + doubles tennis. Padel courts: doubles padel only.
  def self.kind_for_tournament_format(tournament_format)
    tournament_format.to_s == "doubles_padel" ? "padel" : "tennis"
  end

  def self.for_round(round)
    kind = kind_for_tournament_format(round.tournament_format)
    where(club_id: round.club_id, court_kind: kind).order(:name)
  end
end
