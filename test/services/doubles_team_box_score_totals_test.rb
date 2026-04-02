# frozen_string_literal: true

require "test_helper"

class DoublesTeamBoxScoreTotalsTest < ActiveSupport::TestCase
  test "compute_results matches MatchesController for two side payloads" do
    controller = MatchesController.new
    payloads = [
      { score_set1: 4, score_set2: 4, score_tiebreak: 0 },
      { score_set1: 2, score_set2: 1, score_tiebreak: 0 }
    ]
    assert_equal controller.send(:compute_results, payloads), DoublesTeamBoxScoreTotals.compute_results(payloads)
  end
end
