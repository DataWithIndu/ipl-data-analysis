-- ============================================================
-- IPL Data Analysis (2008-2024) | Level 2: Intermediate Analysis
-- Tool: SQL Server
-- Dataset: IPL Complete Dataset (Kaggle)
-- ============================================================
-- What this covers:
--   Complete batter profiles (average, strike rate, boundary %),
--   bowler performance split by game phase (powerplay / middle / death),
--   venue scoring analysis by city, season-wise run and six trends.
-- ============================================================

USE PortfolioProjects;


-- Q7. Batter performance — Average + Strike Rate + Boundary %
-- Business use: Complete batter profile for auction analysis
SELECT 
    batter,
    COUNT(DISTINCT match_id) AS matches,
    SUM(CAST(batsman_runs AS INT)) AS total_runs,
    COUNT(*) AS balls_faced,
    SUM(CASE WHEN is_wicket = '1' 
             AND player_dismissed = batter THEN 1 ELSE 0 END) AS dismissals,
    ROUND(SUM(CAST(batsman_runs AS INT)) * 1.0 / 
          NULLIF(SUM(CASE WHEN is_wicket = '1' 
                          AND player_dismissed = batter THEN 1 ELSE 0 END), 0)
    , 2) AS batting_avg,
    ROUND(SUM(CAST(batsman_runs AS INT)) * 100.0 / COUNT(*), 2) AS strike_rate,
    SUM(CASE WHEN batsman_runs = '4' THEN 1 ELSE 0 END) AS fours,
    SUM(CASE WHEN batsman_runs = '6' THEN 1 ELSE 0 END) AS sixes,
    ROUND(
        (SUM(CASE WHEN batsman_runs = '4' THEN 1 ELSE 0 END) + 
         SUM(CASE WHEN batsman_runs = '6' THEN 1 ELSE 0 END)) * 100.0 
        / COUNT(*), 2) AS boundary_pct
FROM deliveries
GROUP BY batter
HAVING COUNT(DISTINCT match_id) >= 20
ORDER BY total_runs DESC;


-- Q8. Bowler performance — Economy + Strike Rate by game phase
-- Business use: Which bowlers are best in powerplay vs death overs?
WITH phase_stats AS (
    SELECT 
        bowler,
        CASE 
            WHEN CAST(over_number AS INT) BETWEEN 1 AND 6 THEN 'Powerplay'
            WHEN CAST(over_number AS INT) BETWEEN 7 AND 15 THEN 'Middle Overs'
            WHEN CAST(over_number AS INT) BETWEEN 16 AND 20 THEN 'Death Overs'
        END AS game_phase,
        COUNT(*) AS balls_bowled,
        SUM(CAST(total_runs AS INT)) AS runs_conceded,
        SUM(CASE WHEN is_wicket = '1' 
                 AND dismissal_kind NOT IN 
                 ('run out', 'retired hurt', 'obstructing the field') 
                 THEN 1 ELSE 0 END) AS wickets,
        ROUND(SUM(CAST(total_runs AS INT)) * 6.0 / COUNT(*), 2) AS economy,
        ROUND(COUNT(*) * 1.0 / NULLIF(SUM(CASE WHEN is_wicket = '1' 
                 AND dismissal_kind NOT IN 
                 ('run out', 'retired hurt', 'obstructing the field') 
                 THEN 1 ELSE 0 END), 0), 2) AS bowling_strike_rate
    FROM deliveries
    WHERE CAST(over_number AS INT) BETWEEN 1 AND 20
    GROUP BY bowler,
        CASE 
            WHEN CAST(over_number AS INT) BETWEEN 1 AND 6 THEN 'Powerplay'
            WHEN CAST(over_number AS INT) BETWEEN 7 AND 15 THEN 'Middle Overs'
            WHEN CAST(over_number AS INT) BETWEEN 16 AND 20 THEN 'Death Overs'
        END
    HAVING COUNT(*) >= 60
),
ranked AS (
    SELECT *,
        RANK() OVER (PARTITION BY game_phase ORDER BY economy ASC) AS economy_rank
    FROM phase_stats
)
SELECT 
    game_phase,
    economy_rank,
    bowler,
    balls_bowled,
    wickets,
    economy,
    bowling_strike_rate
FROM ranked
WHERE economy_rank <= 10
ORDER BY game_phase, economy_rank;


-- Q9. Venue analysis — Which grounds are highest scoring?
-- Business use: Home ground advantage + pitch strategy
SELECT TOP 15
    m.city,
    COUNT(DISTINCT m.id) AS matches_played,
    ROUND(AVG(CAST(d.total_runs AS FLOAT)), 2) AS avg_runs_per_ball,
    SUM(CAST(d.total_runs AS INT)) AS total_runs_scored,
    SUM(CASE WHEN d.batsman_runs = '6' THEN 1 ELSE 0 END) AS total_sixes
FROM matches m
JOIN deliveries d ON m.id = d.match_id
WHERE m.venue NOT LIKE '%"%'
  AND m.city IS NOT NULL
  AND m.city NOT LIKE '%"%'
GROUP BY m.city
HAVING COUNT(DISTINCT m.id) >= 5
ORDER BY avg_runs_per_ball DESC;


-- Q10. Season wise run scoring trend
-- Business use: Is IPL becoming more batting friendly over years?
SELECT 
    m.season,
    COUNT(DISTINCT m.id) AS total_matches,
    SUM(CAST(d.total_runs AS INT)) AS season_total_runs,
    ROUND(SUM(CAST(d.total_runs AS INT)) * 1.0 / 
          COUNT(DISTINCT m.id), 2) AS avg_runs_per_match,
    SUM(CASE WHEN d.batsman_runs = '6' THEN 1 ELSE 0 END) AS total_sixes,
    SUM(CASE WHEN d.batsman_runs = '4' THEN 1 ELSE 0 END) AS total_fours
FROM matches m
JOIN deliveries d ON m.id = d.match_id
GROUP BY m.season
ORDER BY m.season;
