USE PortfolioProjects;

-- ============================================================
--        IPL DATA ANALYSIS | DataWithIndu
--        Tool: SQL Server
--        Dataset: IPL Complete Dataset 2008-2024
--        Tables: matches (2180 rows), deliveries (260,920 rows)
-- ============================================================


-- ============================================================
--                    LEVEL 1: BASIC ANALYSIS
-- ============================================================

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


-- ============================================================
--                 LEVEL 2: INTERMEDIATE ANALYSIS
-- ============================================================

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



/*
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
ORDER BY game_phase, economy ASC;
*/


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


-- ============================================================
--                 LEVEL 3: ADVANCED ANALYSIS
-- ============================================================

-- Q11. Custom Batter Performance Index (Weighted Scoring)
-- Business use: Single score to rank batters for auction bidding
USE PortfolioProjects;

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
USE PortfolioProjects;

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
USE PortfolioProjects;

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
USE PortfolioProjects;

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
USE PortfolioProjects;

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


-- ============================================================
--              LEVEL 4: STORED PROCEDURES + VIEWS
-- ============================================================

-- Stored Procedure 1: Head to Head — Any Batter vs Any Bowler
-- Business use: Pre-match tactical analysis
CREATE PROCEDURE GetHeadToHead
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

/*
EXEC GetHeadToHead @Batter = 'V Kohli', @Bowler = 'SL Malinga'; 
--we can run it for any batter and bowler to get their head to head stats
*/

-- Stored Procedure 2: Full Player Profile on demand
-- Business use: Instant player report for any name
CREATE PROCEDURE GetPlayerProfile
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

/*
EXEC GetPlayerProfile @PlayerName = 'V Kohli'; 
--we can run it for any player name to get their batting and bowling profile
*/

-- View 1: Season Summary Dashboard
-- Business use: Quick season overview anytime
CREATE VIEW vw_IPL_Season_Summary AS
SELECT 
    m.season,
    COUNT(DISTINCT m.id) AS total_matches,
    SUM(CAST(d.total_runs AS INT)) AS total_runs,
    ROUND(SUM(CAST(d.total_runs AS INT)) * 1.0 / 
          COUNT(DISTINCT m.id), 2) AS avg_runs_per_match,
    SUM(CASE WHEN d.batsman_runs = '6' THEN 1 ELSE 0 END) AS total_sixes,
    SUM(CASE WHEN d.batsman_runs = '4' THEN 1 ELSE 0 END) AS total_fours,
    SUM(CASE WHEN d.is_wicket = '1' THEN 1 ELSE 0 END) AS total_wickets,
    m.season AS display_season
FROM matches m
JOIN deliveries d ON m.id = d.match_id
GROUP BY m.season;

SELECT * FROM vw_IPL_Season_Summary ORDER BY season; 
-- we can run this view anytime to get a quick summary of each IPL season with total matches, runs, wickets, and boundary counts. 

-- View 2: Team Performance Overview
-- Business use: Always up to date team standings

CREATE VIEW vw_Team_Performance AS
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

SELECT * FROM vw_Team_Performance ORDER BY season, win_percentage DESC; 
-- we can run this view anytime to see how each team performed in each season with matches played, wins, losses, and win percentage. 