# Multi-Format Rollout Sequence

1. Deploy schema migrations (`rounds.tournament_format`, `teams`, `team_memberships`, `team_match_scores`, `team_box_scores`, and `matches.team_a_id/team_b_id`).
2. Backfill existing rounds to `singles_tennis` (default already applied by migration).
3. Enable context resolver + login chooser routing in production.
4. Start creating doubles rounds and teams for selected pilot clubs.
5. Enable doubles score entry and team ranking for pilot rounds.
6. Validate rules content switching (`singles_tennis`, `doubles_tennis`, `doubles_padel`) in all locales.
7. Roll out to all clubs after pilot validation.
