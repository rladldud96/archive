/* Project: Marketing Funnel Performance Analysis
  -- QUERY #1: Calculate the conversion rate from MQL to Opportunity by referral channel.
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


-- QUERY #2: Account Segmentation by Source & Seats Tier with Conversion Rate

WITH account_segmentation AS (
    SELECT 
        account_id,
        referral_source,
        
        -- 1. Segment accounts into tiers based on the number of seats (business size)
        CASE 
            WHEN seats >= 20 THEN 'High-Volume (Enterprise)'
            WHEN seats >= 5 THEN 'Mid-Volume (Mid-Market)'
            ELSE 'Low-Volume (SMB)'
        END AS seats_tier,
        
        -- 2. Define conversion: 1 if they upgraded to a paid plan, 0 if they stayed on 'Free'
        CASE 
            WHEN plan_tier != 'Free' THEN 1 
            ELSE 0 
        END AS is_paid
    FROM `ravenstack-analysis-496219.ravenstack_data.accounts` 
)

SELECT 
    referral_source,
    seats_tier,
    COUNT(*) AS total_accounts,
    SUM(is_paid) AS paid_conversion_count,
    
    -- 3. Calculate the final Paid Conversion Rate (%) rounded to 1 decimal place
    ROUND(100.0 * SUM(is_paid) / COUNT(*), 1) AS conversion_rate_pct
FROM account_segmentation
GROUP BY referral_source, seats_tier
ORDER BY referral_source, conversion_rate_pct DESC;


-- QUERY #3: Funnel Analysis (MQL -> SAL -> SQL -> Opportunity)

WITH funnel_stages AS (
    SELECT 
        account_id,
        1 AS is_mql,
        CASE WHEN plan_tier != 'Free' AND plan_tier IS NOT NULL THEN 1 ELSE 0 END AS is_sal,
        CASE WHEN plan_tier IN ('Pro', 'Enterprise') THEN 1 ELSE 0 END AS is_sql,
        CASE WHEN plan_tier = 'Enterprise' THEN 1 ELSE 0 END AS is_opp
    FROM `ravenstack-analysis-496219.ravenstack_data.accounts`
),
funnel_counts AS (
    SELECT 
        SUM(is_mql) AS mql_count,
        SUM(is_sal) AS sal_count,
        SUM(is_sql) AS sql_count,
        SUM(is_opp) AS opp_count
    FROM funnel_stages
),
unpivoted_funnel AS (
    SELECT 1 AS stage_num, '1. MQL' AS stage, mql_count AS account_count FROM funnel_counts
    UNION ALL
    SELECT 2, '2. SAL', sal_count FROM funnel_counts
    UNION ALL
    SELECT 3, '3. SQL', sql_count FROM funnel_counts
    UNION ALL
    SELECT 4, '4. Opportunity', opp_count FROM funnel_counts
)
SELECT 
    stage,
    account_count,
    ROUND(
        SAFE_DIVIDE(account_count, FIRST_VALUE(account_count) OVER (ORDER BY stage_num)) * 100, 
        1
    ) AS total_conversion_pct,

    ROUND(
        SAFE_DIVIDE(
            account_count, 
            COALESCE(LAG(account_count, 1) OVER (ORDER BY stage_num), account_count)
        ) * 100, 
        1
    ) AS stage_to_stage_conversion_pct
FROM unpivoted_funnel
ORDER BY stage_num;