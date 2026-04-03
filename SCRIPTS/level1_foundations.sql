-- ============================================================
-- IPL Data Analysis (2008-2024) | Level 1: Basic Analysis
-- Tool: SQL Server
-- Dataset: IPL Complete Dataset (Kaggle)
--   matches table    : 2,180 rows
--   deliveries table : 2,60,920 rows
-- ============================================================
-- What this covers:
--   Team win counts and win percentages, toss impact analysis,
--   top run scorers, top wicket takers, season-wise match growth.
--   This is also where most of the dirty data surfaced and was handled.
-- ============================================================

USE PortfolioProjects;


-- Q1. Which teams have won the most matches overall?
-- Business use: Understanding dominant franchises for brand/sponsorship value
SELECT 
    winner,
    COUNT(*) AS total_wins,
    ROUND(COUNT(*) * 100.0 / (
        SELECT COUNT(*) FROM matches WHERE winner IS NOT NULL
    ), 2) AS win_percentage
FROM matches
WHERE winner IS NOT NULL
  AND winner NOT IN ('bat', 'field', 'NA')  -- removes dirty data
GROUP BY winner
ORDER BY total_wins DESC;


-- Q2. How many matches did each team PLAY (not just win)?
-- Business use: Checking team participation across seasons
SELECT team, COUNT(*) AS matches_played
FROM (
    SELECT team1 AS team FROM matches
    UNION ALL
    SELECT team2 AS team FROM matches
) all_teams
WHERE team NOT LIKE '%"%'
  AND TRIM(team) NOT IN (
    'bat', 'field', 'NA',
    'Chepauk', 'Uppal', 'Mohali',
    'Royal Challengers Bengaluru' -- duplicate of Bangalore, same team rebranded
  )
GROUP BY team
ORDER BY matches_played DESC;


-- Q3. Does winning the toss help win the match?
-- Business use: Strategic decision making — bat or field first?
SELECT 
    toss_decision,
    COUNT(*) AS total_matches,
    SUM(CASE WHEN toss_winner = winner THEN 1 ELSE 0 END) AS toss_winner_won,
    ROUND(SUM(CASE WHEN toss_winner = winner THEN 1 ELSE 0 END) * 100.0 
          / COUNT(*), 2) AS win_pct_after_toss
FROM matches
WHERE winner IS NOT NULL
  AND winner NOT IN ('bat', 'field', 'NA')
  AND toss_decision IN ('bat', 'field')
GROUP BY toss_decision;


-- Q4. Top 10 run scorers all time
-- Business use: Identifying marquee players for auction/sponsorship
SELECT TOP 10
    batter,
    SUM(CAST(batsman_runs AS INT)) AS total_runs,
    COUNT(DISTINCT match_id) AS matches_played,
    ROUND(SUM(CAST(batsman_runs AS INT)) * 1.0 / 
          COUNT(DISTINCT match_id), 2) AS avg_runs_per_match
FROM deliveries
GROUP BY batter
ORDER BY total_runs DESC;


-- Q5. Top 10 wicket takers all time
-- Business use: Identifying key bowling assets
SELECT TOP 10
    bowler,
    COUNT(*) AS total_wickets,
    COUNT(DISTINCT match_id) AS matches_played,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT match_id), 2) AS wickets_per_match
FROM deliveries
WHERE is_wicket = '1'
  AND dismissal_kind NOT IN ('run out', 'retired hurt', 'obstructing the field')
GROUP BY bowler
ORDER BY total_wickets DESC;


-- Q6. Season wise match count — how has IPL grown?
-- Business use: League growth trajectory
SELECT 
    season,
    COUNT(*) AS total_matches
FROM matches
GROUP BY season
ORDER BY season;
