-- ============================================================
-- IPL Data Analysis (2008-2024) | Level 3: Advanced Analysis
-- Tool: SQL Server
-- Dataset: IPL Complete Dataset (Kaggle)
-- ============================================================
-- What this covers:
--   Custom Batter Performance Index (weighted scoring model),
--   rolling 5-match team momentum tracker, phase-wise bowler
--   deep dive, partnership analysis, dismissal pattern breakdown
--   for top 20 run scorers.
-- ============================================================

USE PortfolioProjects;


-- Q11. Custom Batter Performance Index (Weighted Scoring)
-- Business use: Single score to rank batters for auction bidding
-- Weights: 40% strike rate, 35% batting average, 25% boundary impact
WITH batting_stats AS (
    SELECT 
        batter,
        COUNT(DISTINCT match_id) AS matches,
        SUM(CAST(batsman_runs AS INT)) AS total_runs,
        COUNT(*) AS balls_faced,
        SUM(CASE WHEN batsman_runs = '4' THEN 1 ELSE 0 END) AS fours,
        SUM(CASE WHEN batsman_runs = '6' THEN 1 ELSE 0 END) AS sixes,
        SUM(CASE WHEN is_wicket = '1' 
                 AND player_dismissed = batter THEN 1 ELSE 0 END) AS dismissals
    FROM deliveries
    GROUP BY batter
    HAVING COUNT(DISTINCT match_id) >= 20
),
performance_calc AS (
    SELECT *,
        ROUND(total_runs * 1.0 / NULLIF(dismissals, 0), 2) AS batting_avg,
        ROUND(total_runs * 100.0 / NULLIF(balls_faced, 0), 2) AS strike_rate,
        ROUND((sixes * 6 + fours * 4) * 100.0 / NULLIF(balls_faced, 0), 2) AS boundary_impact
    FROM batting_stats
),
scored AS (
    SELECT *,
        ROUND(
            (ROUND(total_runs * 1.0 / NULLIF(dismissals, 0), 2) * 0.35) +
            (ROUND(total_runs * 100.0 / NULLIF(balls_faced, 0), 2) * 0.40) +
            (ROUND((sixes * 6 + fours * 4) * 100.0 / NULLIF(balls_faced, 0), 2) * 0.25)
        , 2) AS performance_index
    FROM performance_calc
)
SELECT 
    batter,
    matches,
    total_runs,
    batting_avg,
    strike_rate,
    fours,
    sixes,
    performance_index,
    RANK() OVER (ORDER BY performance_index DESC) AS pi_rank,
    NTILE(4) OVER (ORDER BY performance_index DESC) AS performance_tier
FROM scored
ORDER BY pi_rank
OFFSET 0 ROWS FETCH NEXT 20 ROWS ONLY;


-- Q12. Team Momentum — Rolling 5 match win tracker
-- Business use: Identify teams in form heading into playoffs
WITH team_matches AS (
    SELECT id AS match_id, season, date, team1 AS team, winner 
    FROM matches
    UNION ALL
    SELECT id AS match_id, season, date, team2 AS team, winner 
    FROM matches
),
win_flag AS (
    SELECT *,
        CASE WHEN team = winner THEN 1 ELSE 0 END AS won
    FROM team_matches
),
streaks AS (
    SELECT *,
        SUM(won) OVER (
            PARTITION BY team, season 
            ORDER BY date 
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) AS wins_last_5,
        SUM(won) OVER (
            PARTITION BY team, season 
            ORDER BY date
        ) AS cumulative_wins
    FROM win_flag
),
form_labeled AS (
    SELECT *,
        CASE 
            WHEN wins_last_5 >= 4 THEN 'Excellent Form'
            WHEN wins_last_5 = 3 THEN 'Good Form'
            WHEN wins_last_5 = 2 THEN 'Average Form'
            ELSE 'Poor Form'
        END AS current_form
    FROM streaks
)
SELECT 
    team,
    season,
    SUM(won) AS total_wins,
    COUNT(*) AS total_matches,
    ROUND(SUM(won) * 100.0 / COUNT(*), 2) AS win_pct,
    MAX(wins_last_5) AS best_5match_run,
    SUM(CASE WHEN current_form = 'Excellent Form' THEN 1 ELSE 0 END) AS matches_in_top_form
FROM form_labeled
GROUP BY team, season
ORDER BY season, total_wins DESC;


-- Q13. Bowler Situational Effectiveness — Phase wise deep dive
-- Business use: Which bowlers to use in powerplay vs death?
WITH bowler_phase AS (
    SELECT 
        bowler,
        CASE 
            WHEN CAST(over_number AS INT) BETWEEN 1 AND 6 THEN 'Powerplay'
            WHEN CAST(over_number AS INT) BETWEEN 7 AND 15 THEN 'Middle Overs'
            ELSE 'Death Overs'
        END AS game_phase,
        COUNT(*) AS balls,
        SUM(CAST(total_runs AS INT)) AS runs_given,
        SUM(CASE WHEN is_wicket = '1'
                 AND dismissal_kind NOT IN 
                 ('run out','retired hurt','obstructing the field') 
                 THEN 1 ELSE 0 END) AS wickets
    FROM deliveries
    WHERE CAST(over_number AS INT) BETWEEN 1 AND 20
    GROUP BY bowler,
        CASE 
            WHEN CAST(over_number AS INT) BETWEEN 1 AND 6 THEN 'Powerplay'
            WHEN CAST(over_number AS INT) BETWEEN 7 AND 15 THEN 'Middle Overs'
            ELSE 'Death Overs'
        END
    HAVING COUNT(*) >= 60
),
metrics AS (
    SELECT *,
        ROUND(runs_given * 6.0 / NULLIF(balls, 0), 2) AS economy,
        ROUND(balls * 1.0 / NULLIF(wickets, 0), 2) AS bowling_strike_rate,
        ROUND(runs_given * 1.0 / NULLIF(wickets, 0), 2) AS bowling_avg,
        RANK() OVER (
            PARTITION BY game_phase 
            ORDER BY runs_given * 6.0 / NULLIF(balls, 0) ASC
        ) AS economy_rank
    FROM bowler_phase
)
SELECT 
    bowler,
    game_phase,
    balls,
    wickets,
    economy,
    bowling_strike_rate,
    bowling_avg,
    economy_rank
FROM metrics
WHERE economy_rank <= 10
ORDER BY game_phase, economy_rank;


-- Q14. Partnership Analysis — Best batting pairs
-- Business use: Which opening/middle order pairs are most dangerous?
WITH partnerships AS (
    SELECT 
        match_id,
        inning,
        batter,
        non_striker,
        SUM(CAST(batsman_runs AS INT)) AS runs_contributed,
        COUNT(*) AS balls_together
    FROM deliveries
    GROUP BY match_id, inning, batter, non_striker
),
pair_stats AS (
    SELECT 
        CASE WHEN batter < non_striker 
             THEN batter ELSE non_striker END AS player1,
        CASE WHEN batter < non_striker 
             THEN non_striker ELSE batter END AS player2,
        COUNT(DISTINCT match_id) AS matches_together,
        SUM(runs_contributed) AS total_runs,
        ROUND(SUM(runs_contributed) * 1.0 / 
              COUNT(DISTINCT match_id), 2) AS avg_per_match
    FROM partnerships
    GROUP BY 
        CASE WHEN batter < non_striker 
             THEN batter ELSE non_striker END,
        CASE WHEN batter < non_striker 
             THEN non_striker ELSE batter END
    HAVING COUNT(DISTINCT match_id) >= 10
)
SELECT TOP 20
    player1,
    player2,
    matches_together,
    total_runs,
    avg_per_match,
    RANK() OVER (ORDER BY total_runs DESC) AS partnership_rank
FROM pair_stats
ORDER BY total_runs DESC;


-- Q15. Player Dismissal Patterns — How do top batters get out?
-- Business use: Bowling strategy against specific batters
WITH top_batters AS (
    SELECT TOP 20 batter
    FROM deliveries
    GROUP BY batter
    ORDER BY SUM(CAST(batsman_runs AS INT)) DESC
)
SELECT 
    d.player_dismissed,
    d.dismissal_kind,
    COUNT(*) AS times_dismissed,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER 
          (PARTITION BY d.player_dismissed), 2) AS dismissal_pct
FROM deliveries d
WHERE d.player_dismissed IN (SELECT batter FROM top_batters)
  AND d.is_wicket = '1'
  AND d.dismissal_kind NOT IN ('run out', 'retired hurt', 'obstructing the field')
GROUP BY d.player_dismissed, d.dismissal_kind
ORDER BY d.player_dismissed, times_dismissed DESC;
