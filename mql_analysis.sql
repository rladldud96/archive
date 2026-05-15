/* Project: Marketing Funnel Performance Analysis
  Objective: Calculate the conversion rate from MQL to Opportunity by referral channel.
  Metric: MQL-to-Opportunity Conversion Rate (%)
*/

WITH ChannelStats AS (
    SELECT 
        referral_source AS channel,
        COUNT(account_id) AS total_leads,
        -- Defining 'Opportunity' as accounts that signed up for Pro or Enterprise tiers
        SUM(CASE WHEN plan_tier IN ('Pro', 'Enterprise') THEN 1 ELSE 0 END) AS opportunity_count
    FROM `ravenstack-analysis-496219.ravenstack_data.accounts`
    GROUP BY 1
)
SELECT 
    channel,
    total_leads,
    opportunity_count,
    -- SAFE_DIVIDE prevents 'Division by Zero' errors
    ROUND(SAFE_DIVIDE(opportunity_count, total_leads) * 100, 1) AS conversion_rate_pct
FROM ChannelStats
WHERE total_leads > 0
ORDER BY conversion_rate_pct DESC;

--------------------------------------------------
-- [Analysis 2] Advanced MoM Growth Trend (using LAG)
WITH monthly_mql AS (
    SELECT 
        -- Truncate date to month for time-series
        DATE_TRUNC(signup_date, MONTH) AS analysis_month,
        COUNT(account_id) AS mql_count
    FROM `ravenstack-analysis-496219.ravenstack_data.accounts`
    GROUP BY 1
)

SELECT 
    analysis_month,
    mql_count AS current_month_mql,
    -- LAG() grabs the value from the previous row (the previous month)
    LAG(mql_count) OVER (ORDER BY analysis_month) AS prev_month_mql,
    -- Calculate % Change: ((Current - Prev) / Prev) * 100
    ROUND(
        SAFE_DIVIDE(
            mql_count - LAG(mql_count) OVER (ORDER BY analysis_month),
            LAG(mql_count) OVER (ORDER BY analysis_month)
        ) * 100, 1
    ) AS mom_growth_pct
FROM monthly_mql
ORDER BY analysis_month DESC;

/* Analysis 3: Full Funnel breakdown (MQL -> SAL -> SQL -> Opportunity) */

-- 1. MQL 
SELECT '1. MQL' AS stage, COUNT(account_id) AS lead_count, 1 AS sort_order
FROM `ravenstack-analysis-496219.ravenstack_data.accounts`

UNION ALL

-- 2. SAL
SELECT '2. SAL' AS stage, COUNT(account_id), 2
FROM `ravenstack-analysis-496219.ravenstack_data.accounts` 
WHERE plan_tier != 'Free' AND plan_tier IS NOT NULL

UNION ALL

-- 3. SQL 
SELECT '3. SQL' AS stage, COUNT(account_id), 3
FROM `ravenstack-analysis-496219.ravenstack_data.accounts` 
WHERE plan_tier IN ('Pro', 'Enterprise')

UNION ALL

-- 4. Opportunity 
SELECT '4. Opportunity' AS stage, COUNT(account_id), 4
FROM `ravenstack-analysis-496219.ravenstack_data.accounts` 
WHERE plan_tier = 'Enterprise';