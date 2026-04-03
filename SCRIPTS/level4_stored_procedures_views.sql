-- ============================================================
-- IPL Data Analysis (2008-2024) | Level 4: Stored Procedures + Views
-- Tool: SQL Server
-- Dataset: IPL Complete Dataset (Kaggle)
-- ============================================================
-- What this covers:
--   Two stored procedures for on-demand player lookups,
--   two views for reusable season and team summaries.
--   These make the analysis callable and repeatable without
--   rewriting queries each time.
-- ============================================================

USE PortfolioProjects;


-- Stored Procedure 1: Head to Head — Any Batter vs Any Bowler
-- Business use: Pre-match tactical analysis
-- Usage: EXEC GetHeadToHead @Batter = 'V Kohli', @Bowler = 'SL Malinga'
CREATE OR ALTER PROCEDURE GetHeadToHead
    @Batter NVARCHAR(100),
    @Bowler NVARCHAR(100)
AS
BEGIN
    SELECT 
        batter,
        bowler,
        COUNT(*) AS balls_faced,
        SUM(CAST(batsman_runs AS INT)) AS runs_scored,
        SUM(CASE WHEN batsman_runs = '4' THEN 1 ELSE 0 END) AS fours,
        SUM(CASE WHEN batsman_runs = '6' THEN 1 ELSE 0 END) AS sixes,
        SUM(CASE WHEN player_dismissed = @Batter THEN 1 ELSE 0 END) AS dismissals,
        ROUND(SUM(CAST(batsman_runs AS INT)) * 100.0 / COUNT(*), 2) AS strike_rate,
        ROUND(SUM(CAST(batsman_runs AS INT)) * 1.0 / 
              NULLIF(SUM(CASE WHEN player_dismissed = @Batter 
                              THEN 1 ELSE 0 END), 0), 2) AS batting_avg
    FROM deliveries
    WHERE batter = @Batter AND bowler = @Bowler
    GROUP BY batter, bowler;
END;


-- Stored Procedure 2: Full Player Profile on demand
-- Business use: Instant player report for any name
-- Usage: EXEC GetPlayerProfile @PlayerName = 'V Kohli'
CREATE OR ALTER PROCEDURE GetPlayerProfile
    @PlayerName NVARCHAR(100)
AS
BEGIN
    -- Batting stats
    SELECT 
        'BATTING' AS stat_type,
        batter AS player_name,
        COUNT(DISTINCT match_id) AS matches,
        SUM(CAST(batsman_runs AS INT)) AS total_runs,
        ROUND(SUM(CAST(batsman_runs AS INT)) * 100.0 / COUNT(*), 2) AS strike_rate,
        SUM(CASE WHEN batsman_runs = '4' THEN 1 ELSE 0 END) AS fours,
        SUM(CASE WHEN batsman_runs = '6' THEN 1 ELSE 0 END) AS sixes
    FROM deliveries
    WHERE batter = @PlayerName
    GROUP BY batter;

    -- Bowling stats
    SELECT 
        'BOWLING' AS stat_type,
        bowler AS player_name,
        COUNT(DISTINCT match_id) AS matches,
        COUNT(*) AS balls_bowled,
        SUM(CAST(total_runs AS INT)) AS runs_conceded,
        SUM(CASE WHEN is_wicket = '1' 
                 AND dismissal_kind NOT IN 
                 ('run out','retired hurt','obstructing the field') 
                 THEN 1 ELSE 0 END) AS wickets,
        ROUND(SUM(CAST(total_runs AS INT)) * 6.0 / COUNT(*), 2) AS economy
    FROM deliveries
    WHERE bowler = @PlayerName
    GROUP BY bowler;
END;


-- View 1: Season Summary Dashboard
-- Business use: Quick season overview without recomputing each time
-- Usage: SELECT * FROM vw_IPL_Season_Summary ORDER BY season
CREATE OR ALTER VIEW vw_IPL_Season_Summary AS
SELECT 
    m.season,
    COUNT(DISTINCT m.id) AS total_matches,
    SUM(CAST(d.total_runs AS INT)) AS total_runs,
    ROUND(SUM(CAST(d.total_runs AS INT)) * 1.0 / 
          COUNT(DISTINCT m.id), 2) AS avg_runs_per_match,
    SUM(CASE WHEN d.batsman_runs = '6' THEN 1 ELSE 0 END) AS total_sixes,
    SUM(CASE WHEN d.batsman_runs = '4' THEN 1 ELSE 0 END) AS total_fours,
    SUM(CASE WHEN d.is_wicket = '1' THEN 1 ELSE 0 END) AS total_wickets
FROM matches m
JOIN deliveries d ON m.id = d.match_id
GROUP BY m.season;


-- View 2: Team Performance Overview
-- Business use: Always up to date team standings per season
-- Usage: SELECT * FROM vw_Team_Performance ORDER BY season, win_percentage DESC
CREATE OR ALTER VIEW vw_Team_Performance AS
SELECT
    team,
    season,
    COUNT(*) AS matches_played,
    SUM(CASE WHEN team = winner THEN 1 ELSE 0 END) AS wins,
    SUM(CASE WHEN team != winner THEN 1 ELSE 0 END) AS losses,
    ROUND(SUM(CASE WHEN team = winner THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2) AS win_percentage
FROM (
    SELECT team1 AS team, winner, season FROM matches
    UNION ALL
    SELECT team2 AS team, winner, season FROM matches
) AS all_matches
WHERE winner IS NOT NULL
GROUP BY team, season;
