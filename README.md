# IPL Data Analysis (2008 to 2024)
SQL Server | Advanced SQL | DataWithIndu

---

## What is this project about?

I picked IPL because I wanted to work with a dataset that was large, messy, and interesting enough to ask real questions about. I had zero cricket knowledge going in, which honestly made it better. I wasn't trying to confirm what I already knew, I was just letting the data talk.

The goal was to go beyond basic queries and build something useful. Player rankings, team strategy insights, phase-wise bowler analysis. The kind of stuff a real franchise analyst might actually care about.

---

## About the Data

Got this dataset from Kaggle. It has IPL match and ball-by-ball data from 2008 to 2024.

- matches table: 2,180 matches
- deliveries table: 2,60,920 ball by ball records

Dataset link: https://www.kaggle.com/datasets/patrickb1912/ipl-complete-dataset-20082020

---

## Setup

Used SQL Server on Mac via Docker. Had to use pipe ( | ) as the separator instead of comma while importing because some venue names had commas in them, like "Punjab Cricket Association Stadium, Mohali". Loaded using BULK INSERT in VS Code.

---

## Project Structure

The project is split into 4 levels, each building on the previous one.

**Level 1: Foundations**

Basic team and player stats. Win counts, toss analysis, top scorers, top wicket takers, season growth over 17 years. This is also where I first ran into dirty data. Venue names were leaking into team columns, stray quote characters were creating duplicate entries, and toss decisions were showing up in the winner column. Cleaning this iteratively took a while but was one of the more realistic parts of the whole project.

**Level 2: Intermediate Analysis**

Batter profiles with average, strike rate and boundary percentage. Bowler performance split by game phase (powerplay, middle overs, death overs). Venue scoring analysis grouped by city. Season-wise run and six trends across all 17 seasons.

**Level 3: Advanced Analysis**

Built a custom Batter Performance Index using weighted scoring (40% strike rate, 35% batting average, 25% boundary impact). PD Salt ranks first despite having far fewer total runs than Kohli, which says a lot about what actually wins T20 games. Also built a rolling 5-match team momentum tracker using window functions, phase-wise bowler effectiveness rankings, partnership analysis across all batter pairs, and dismissal pattern breakdowns for the top 20 run scorers.

**Level 4: Stored Procedures and Views**

Two stored procedures. One takes any batter and bowler name as input and returns their full head-to-head stats on demand. The other returns a complete player profile with batting and bowling stats in a single call. Two views for instant season summaries and team standings without recomputing every time.

---

## Key Findings

**Teams and Strategy**

Mumbai Indians' dominance is not just a perception thing. 256 wins and 11.74% of all IPL matches across 17 seasons puts them clearly ahead of every other franchise. KKR (228) and CSK (217) form a second tier but there is a visible gap.

Winning the toss matters less than what you decide after winning it. Teams that chose to field first won 55.4% of the time compared to 45.6% for teams that batted first. The decision is more important than the coin flip.

Rajasthan Royals won the very first IPL season in 2007/08 with an 81.25% win rate, 13 wins from 16 games. Mumbai Indians that same season had only 38.46%. The team that became the most dominant franchise in IPL history started near the bottom.

RCB has struggled since season one, 28.57% win rate in 2007/08, and that pattern of strong individual performances but inconsistent team results shows up repeatedly across seasons. Deccan Chargers went from wooden spoon in 2007/08 to IPL champions in 2009, which shows how quickly things can flip.

Bengaluru is the highest scoring city in IPL with an average of 1.50 runs per ball. Mumbai, despite hosting the most matches (173), averages only 1.35, meaning Wankhede is more balanced than its reputation suggests.

**Batting**

Virat Kohli leads all-time runs with 8,014 across 244 matches but DA Warner averages 35.69 runs per match compared to Kohli's 32.84. Total runs is not always the right metric.

AB de Villiers had the highest batting average (42.47) AND the highest strike rate (148.58) among the top 10 batters simultaneously. He is the only batter to lead both metrics at the same time, which makes him arguably the most complete batter in IPL history by the numbers.

The custom Performance Index built in this project ranks PD Salt first despite him having only 653 total runs. His strike rate of 169.61 drives the score, which reflects how T20 actually rewards efficiency over accumulation.

CH Gayle has the highest boundary percentage at 21.81%, meaning nearly 1 in 5 balls he faced went to the boundary. The most explosive hitting pattern in the top 10.

AB de Villiers and Kohli together scored 3,040 runs across 77 matches, the most prolific partnership in IPL history. Kohli appears in 3 of the top 4 partnerships overall, suggesting he elevates whoever bats with him.

Caught dismissals dominate for every top batter at 65 to 68%, which is not a personal weakness but a reflection of T20's aggressive aerial style. The more interesting numbers are in the secondary dismissal types. Rahane has an 11.56% LBW rate, significantly higher than others, consistent with his front-foot technique. Gayle has the lowest stumped percentage at 2.42%, meaning he is more conservative against spin than his image suggests.

**Bowling**

JJ Bumrah has the best wickets per match ratio in the top 10 at 1.95, meaning he takes almost 2 wickets every game despite playing fewer matches than most others on the list. Efficiency matters more than total count.

SP Narine bowled 2,187 balls in middle overs alone, nearly three times more than the next bowler in that phase. Franchises have consistently trusted him in the middle overs for over a decade.

Rashid Khan is the only spinner to appear in the death overs top 10 by economy. Conventional thinking says you do not bowl spinners in death overs but the data disagrees for Rashid specifically.

Sohail Tanvir and M Theekshana share the best death over economy at 6.73, ahead of more well-known names. Hidden performers exist well outside the headline players.

MM Ali has the best powerplay economy at 5.01, remarkably low for a phase where batters have fielding restrictions in their favour.

**Trends**

IPL has become measurably more batting friendly over 17 years. Average runs per match grew from 309 in 2007/08 to 365 in 2024, an 18% increase. Total sixes doubled from 623 to 1,261 in the same period.

2024 is the highest scoring season in IPL history. The trend is still accelerating, not plateauing.

The 2020/21 season was played in UAE due to COVID. Scoring stayed at 323 average runs per match, close to normal levels, which suggests the improvement in batting quality over the years is genuine and not just a product of home conditions.

---

## Data Cleaning Notes

A few things I ran into while working with this dataset:

- Venue names leaking into team columns in certain rows. 
- Stray quote characters causing the same team or venue to appear twice. 
- Invisible whitespace around values that broke standard filters and needed LTRIM and RTRIM to fix.
- The same franchise appearing under different names across seasons (Delhi Daredevils became Delhi Capitals, Kings XI Punjab became Punjab Kings, and so on).
- Toss decisions appearing in the winner column.

Each issue needed a different fix. This part of the project was more useful than expected.

---

## SQL Concepts Used

- CTEs (multi-layer)
- Window Functions (RANK, DENSE_RANK, NTILE, LAG, rolling SUM)
- Stored Procedures with parameters
- Views
- UNION ALL
- Subqueries
- NULLIF for edge case handling
- CAST and CASE WHEN
- HAVING, GROUP BY, Aggregate Functions
- String Functions (LTRIM, RTRIM, NOT LIKE)
- JOINs

---

## Future Scope

Planning to add a dashboard layer on top of this analysis once I pick up a visualisation tool.

---

Built by Indu Sharma
github.com/DataWithIndu
