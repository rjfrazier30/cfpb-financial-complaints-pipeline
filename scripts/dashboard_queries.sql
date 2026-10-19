- ============================================================
-- 1. COMPANY SCORECARD OVERVIEW
-- Pulls each company's headline KPIs from the scorecard mart:
-- total complaint volume, timely response %, and dispute rate %.
-- Chart type: Bar chart — COMPANY on X-axis, TIMELY_RESPONSE_PCT on Y-axis.
-- Note: All companies show ~10,000 total complaints because
-- the CFPB API caps at 10k per query, so the volume column
-- isn't useful for comparison — the rates are what matter.
-- ============================================================
SELECT
    company,
    total_complaints,
    timely_response_pct,
    dispute_rate_pct
FROM CFPB_ANALYTICS.DEV_MARTS.RPT_COMPANY_SCORECARD
ORDER BY total_complaints DESC;


-- ============================================================
-- 2. TIMELINESS & DISPUTE RATE — LAST 12 MONTHS
-- Averages each company's monthly timely-response % and dispute
-- rate over the trailing 12 months for a recent performance view.
-- DATEADD('month', -12, CURRENT_DATE()) filters to the last year.
-- ROUND(..., 1) keeps one decimal place for readability.
-- Chart type: Bar chart — COMPANY on X-axis, AVG_TIMELY_PCT on Y-axis.
-- Note: Set Y-axis min to ~85 to see the differences — otherwise
-- all bars look the same since they cluster near 95-100%.
-- ============================================================
SELECT
    company,
    ROUND(AVG(timely_response_pct), 1) AS avg_timely_pct,
    ROUND(AVG(dispute_rate_pct), 1) AS avg_dispute_pct
FROM CFPB_ANALYTICS.DEV_INTERMEDIATE.INT_COMPANY_COMPLAINT_METRICS
WHERE complaint_month >= DATEADD('month', -12, CURRENT_DATE())
GROUP BY company
ORDER BY avg_timely_pct DESC;


-- ============================================================
-- 3. SUBMISSION CHANNELS WITH PERCENTAGES
-- Shows how consumers file complaints — Web, Referral, Phone,
-- Mail, etc. The window function SUM(COUNT(*)) OVER() gives the
-- grand total across all channels, so dividing each channel's
-- count by that produces the percentage share.
-- Chart type: Pie chart — SUBMISSION_CHANNEL as label, TOTAL_COMPLAINTS as value.
-- Note: Web dominates, which reflects the digital-first push
-- in financial services.
-- ============================================================
SELECT
    submission_channel,
    COUNT(*) AS total_complaints,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_total
FROM CFPB_ANALYTICS.DEV_MARTS.FCT_COMPLAINTS
GROUP BY submission_channel
ORDER BY total_complaints DESC;


-- ============================================================
-- 4. COMPLAINTS BY PRODUCT WITH DISPUTE RATE
-- Shows which financial products generate the most complaints —
-- credit cards, mortgages, checking accounts, etc. The CASE
-- statement counts rows where is_consumer_disputed is TRUE,
-- then divides by total rows for that product to get the rate.
-- Chart type: Bar chart — PRODUCT on X-axis, TOTAL_COMPLAINTS on Y-axis.
-- Note: Add DISPUTE_PCT as a second Y-axis column to compare
-- volume vs. consumer dissatisfaction side by side.
-- ============================================================
SELECT
    product,
    COUNT(*) AS total_complaints,
    ROUND(SUM(CASE WHEN is_consumer_disputed THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS dispute_pct
FROM CFPB_ANALYTICS.DEV_MARTS.FCT_COMPLAINTS
GROUP BY product
ORDER BY total_complaints DESC;


-- ============================================================
-- 5. SUBMISSION CHANNELS (SIMPLE)
-- Same idea as #3 but without the percentage calculation —
-- just the raw count per channel for a quick visual breakdown.
-- Chart type: Pie chart — SUBMISSION_CHANNEL as label, TOTAL_COMPLAINTS as value.
-- ============================================================
SELECT
    submission_channel,
    COUNT(*) AS total_complaints
FROM CFPB_ANALYTICS.DEV_MARTS.FCT_COMPLAINTS
GROUP BY submission_channel
ORDER BY total_complaints DESC;