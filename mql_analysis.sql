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
    FROM `your_project.ravenstack_data.accounts`
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