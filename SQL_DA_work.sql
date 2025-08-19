use Nifty100
select top 5 *
from [dbo].[Nifty_final_df];

--Write a query to find the highest and lowest Close price for each year.
SELECT
	YEAR(Date) as year,
	ROUND(MIN(high),2) AS LOWEST_CLOSE,
	ROUND(MAX(high),2) AS HIGHEST_CLOSE
FROM 
Nifty_final_df
GROUP BY
	YEAR(Date)
ORDER BY
	YEAR;

--Write a query to get the top 10 highest single-day gains in Close price.
SELECT TOP 10
    DATE,
	YEAR([Date]) AS year,
    [Open],
    [Close],
    ([Close] - [Open]) AS gain_value,
    ROUND((([Close] - [Open]) / [Open]) * 100, 2) AS per_gain
FROM Nifty_final_df
ORDER BY gain_value,per_gain DESC;

--Write a query to get the top 10 worst single-day losses.
SELECT TOP 10
	DATE,
	YEAR([DATE]) AS YEAR,
	[Open],
	[Close],
	([Close] -[Open]) as gain_value,
	round((([close] - [open]) / [open]) * 100,2) as per_gain
from
	Nifty_final_df
where year(Date) > 2006
ORDER BY gain_value,per_gain asc;

--Write a query to calculate the average monthly return across all years.
WITH MONTHLY_RETURN AS (
    SELECT
        Date,
        YEAR(Date) AS Year,
        MONTH(Date) AS Month,
        FIRST_VALUE([Close]) OVER (
            PARTITION BY YEAR(Date), MONTH(Date) 
            ORDER BY Date ASC
        ) AS START_CLOSE,
        LAST_VALUE([Close]) OVER (
            PARTITION BY YEAR(Date), MONTH(Date) 
            ORDER BY Date ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS END_CLOSE
    FROM Nifty_final_df
)
SELECT
    Year,
    Month,
    CAST((END_CLOSE - START_CLOSE) * 100.0 / START_CLOSE AS DECIMAL(10,2)) AS Monthly_Return
FROM MONTHLY_RETURN
GROUP BY Year, Month, START_CLOSE, END_CLOSE
ORDER BY Year, Month;

--Write a query to calculate yearly returns % ((last_close - first_close)/first_close * 100).
with yearly_return as (
SELECT
	Year(Date) as year,
	FIRST_VALUE([Close]) over(PARTITION BY YEAR(Date) ORDER BY Date asc) as first_close,
	LAST_VALUE([Close])  over(PARTITION BY YEAR(Date) ORDER BY Date asc 
		rows between unbounded preceding and unbounded following ) as last_close
FROM Nifty_final_df)
select
	Distinct(
	year),
	round((last_close - first_close ) / first_close * 100,2) as yearly_return
from
	yearly_return
Order BY
	year;

--Write a query to identify the best and worst performing year.

WITH yearly_return AS (
    SELECT
        YEAR([Date]) AS year,
        FIRST_VALUE([Close]) OVER (
            PARTITION BY YEAR([Date]) ORDER BY [Date] ASC
        ) AS first_close,
        LAST_VALUE([Close]) OVER (
            PARTITION BY YEAR([Date]) ORDER BY [Date] ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_close
    FROM Nifty_final_df
),
yearly_calc AS (
    SELECT
        year,
        ROUND((last_close - first_close) / first_close * 100, 2) AS yearly_return
    FROM yearly_return
    GROUP BY year, first_close, last_close
),
ranked AS (
    SELECT 
        year,
        yearly_return,
        ROW_NUMBER() OVER (ORDER BY yearly_return DESC) AS rn_desc,
        ROW_NUMBER() OVER (ORDER BY yearly_return ASC)  AS rn_asc
    FROM yearly_calc
)
-- Final best and worst performing year
SELECT 
    MAX(CASE WHEN rn_desc = 1 THEN year END) AS best_year,
    MAX(CASE WHEN rn_desc = 1 THEN yearly_return END) AS best_return,
    MAX(CASE WHEN rn_asc = 1 THEN year END) AS worst_year,
    MAX(CASE WHEN rn_asc = 1 THEN yearly_return END) AS worst_return
FROM ranked;

--Write a query to calculate the volatility per year (std deviation of daily returns).
WITH daily_returns AS (
    SELECT
        Date,
        YEAR(Date) AS year,
        [Close],
        LAG([Close]) OVER (ORDER BY Date) AS prev_close,
        CAST([Close] - LAG([Close]) OVER (ORDER BY Date) AS FLOAT) 
            / NULLIF(LAG([Close]) OVER (ORDER BY Date), 0) AS daily_return
    FROM Nifty_final_df
)
SELECT
    year,
    ROUND(STDEV(daily_return), 4) AS volatility
FROM daily_returns
WHERE daily_return IS NOT NULL
GROUP BY year
ORDER BY year;

--Write a query to identify the longest bullish streak (consecutive days Close > previous Close).
WITH price_diff AS (
    SELECT
        Date,
        [Close],
        LAG([Close]) OVER (ORDER BY Date) AS prev_close,
        CASE 
            WHEN [Close] > LAG([Close]) OVER (ORDER BY Date) THEN 1 
            ELSE 0 
        END AS is_bullish
    FROM Nifty_final_df
),
streaks AS (
    SELECT
        Date,
        [Close],
        is_bullish,
        SUM(CASE WHEN is_bullish = 0 THEN 1 ELSE 0 END) 
            OVER (ORDER BY Date ROWS UNBOUNDED PRECEDING) AS grp
    FROM price_diff
),
bullish_groups AS (
    SELECT
        grp,
        COUNT(*) AS streak_length
    FROM streaks
    WHERE is_bullish = 1
    GROUP BY grp
)
SELECT TOP 1
    streak_length AS longest_bullish_streak
FROM bullish_groups
ORDER BY streak_length DESC;

-- Write a query to calculate the moving average (50-day, 200-day) of Close price.
--50 - DAY
SELECT
	DATE,
	AVG([Close]) over(ORDER BY DATE ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
	) AS ma_50
FROM
	Nifty_final_df
ORDER BY DATE;

--100 - DAY
SELECT
    Date,
    [Close],
AVG([Close]) OVER (
        ORDER BY Date
        ROWS BETWEEN 199 PRECEDING AND CURRENT ROW
    ) AS MA_200
FROM Nifty_final_df
ORDER BY Date;

--Write a query to find correlation between Open and Close prices.
SELECT
    ( (COUNT(*) * SUM([Open] * [Close])) - (SUM([Open]) * SUM([Close])) ) /
    (SQRT( (COUNT(*) * SUM([Open] * [Open])) - POWER(SUM([Open]), 2) ) *
          SQRT( (COUNT(*) * SUM([Close] * [Close])) - POWER(SUM([Close]), 2) )
    ) AS Correlation_Open_Close
FROM Nifty_final_df;

--Write a query to create a dashboard table with Year, Avg Close, Annual Return %, Volatility.
WITH Daily AS (
    SELECT 
        Date,
        YEAR(Date) AS Yr,
        [Close],
        ( [Close] - LAG([Close]) OVER (ORDER BY Date) ) / LAG([Close]) OVER (ORDER BY Date) AS DailyReturn
    FROM Nifty_final_df
)
SELECT 
    Yr AS Year,
    AVG([Close]) AS Avg_Close,
    (MAX([Close]) - MIN([Close])) * 100.0 / MIN([Close]) AS Annual_Return_Percent,
    STDEV(DailyReturn) AS Volatility
FROM Daily
GROUP BY Yr
ORDER BY Yr;

--Write a query to detect anomalies where daily return > +5% or < -5%.
WITH Returns AS (
    SELECT 
        Date,
        [Close],
        ( [Close] - LAG([Close]) OVER (ORDER BY Date) ) / LAG([Close]) OVER (ORDER BY Date) * 100 AS DailyReturnPct
    FROM Nifty_final_df
)
SELECT *
FROM Returns
WHERE DailyReturnPct > 5 OR DailyReturnPct < -5
ORDER BY Date;

--Write a query to rank months by performance (highest avg return).
WITH DailyReturns AS (
    SELECT 
        Date,
        ( [Close] - LAG([Close]) OVER (ORDER BY Date) ) * 1.0 / LAG([Close]) OVER (ORDER BY Date) AS DailyReturn
    FROM Nifty_final_df
)
, Monthly AS (
    SELECT 
        YEAR(Date) AS Yr,
        MONTH(Date) AS Mn,
        AVG(DailyReturn) AS AvgDailyReturn
    FROM DailyReturns
    WHERE DailyReturn IS NOT NULL
    GROUP BY YEAR(Date), MONTH(Date)
)
SELECT *,
       RANK() OVER (ORDER BY AvgDailyReturn DESC) AS PerformanceRank
FROM Monthly
ORDER BY PerformanceRank;


--Write a query to find pre-election vs post-election year performance (extra domain insight).
WITH Daily AS (
    SELECT 
        YEAR(Date) AS Yr,
        ( [Close] - LAG([Close]) OVER (ORDER BY Date) ) / LAG([Close]) OVER (ORDER BY Date) AS DailyReturn
    FROM Nifty_final_df
)
SELECT 
    CASE 
        WHEN Yr IN (2013, 2018, 2023) THEN 'Pre-Election'
        WHEN Yr IN (2015, 2020, 2025) THEN 'Post-Election'
        ELSE 'Other'
    END AS Period,
    Yr,
    AVG(DailyReturn) * 100 AS AvgReturnPct
FROM Daily
GROUP BY Yr
ORDER BY Yr;

--Write a query to predict 2026 expected return using historical average return (simple baseline).
WITH Annual AS (
    SELECT 
        YEAR(Date) AS Yr,
        (MAX([Close]) - MIN([Close])) * 1.0 / MIN([Close]) AS AnnualReturn
    FROM Nifty_final_df
    GROUP BY YEAR(Date)
)
SELECT 
    AVG(AnnualReturn) * 100 AS HistoricalAvgReturnPct,
    '2026' AS Predicted_Year,
    AVG(AnnualReturn) * 100 AS Expected_2026_ReturnPct
FROM Annual;


