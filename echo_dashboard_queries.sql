-- ============================================================
-- Amazon Echo Dot 2 — Customer Review Analysis
-- Author: Donson Hoang
-- Tool: MySQL
-- Dataset: Amazon Echo Dot 2 customer reviews (6,855 rows)
--
-- I scraped and cleaned this dataset from Amazon product
-- review pages. After loading it into MySQL, I wrote these
-- queries to power a dashboard exploring customer sentiment,
-- rating trends, and product feedback patterns.
--
-- Table: echo_reviews
-- Columns:
--   title            VARCHAR(255)
--   review_text      TEXT
--   review_color     VARCHAR(50)    -- 'Black' or 'White'
--   user_verified    VARCHAR(50)    -- 'Verified Purchase' or ''
--   review_date      VARCHAR(20)    -- stored as 'M/D/YYYY'
--   rating           TINYINT
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- SECTION 1: Overview KPIs
-- These four numbers go in the top summary cards.
-- ────────────────────────────────────────────────────────────

-- How many reviews are we working with?
SELECT COUNT(*) AS total_reviews
FROM echo_reviews;


-- Overall average star rating
SELECT ROUND(AVG(rating), 2) AS avg_rating
FROM echo_reviews
WHERE rating IS NOT NULL;


-- What percentage of reviews are 5 stars?
-- I wanted to show this as a headline number since it's striking (~64%)
SELECT
    COUNT(*)                                                          AS total_reviews,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END)                      AS five_star_count,
    ROUND(
        100.0 * SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) / COUNT(*),
    1)                                                                AS five_star_pct
FROM echo_reviews
WHERE rating IS NOT NULL;


-- Verified purchase rate — important for trust signal analysis
SELECT
    COUNT(*)                                                                   AS total_reviews,
    SUM(CASE WHEN user_verified = 'Verified Purchase' THEN 1 ELSE 0 END)      AS verified_count,
    ROUND(
        100.0 * SUM(CASE WHEN user_verified = 'Verified Purchase' THEN 1 ELSE 0 END) / COUNT(*),
    1)                                                                         AS verified_pct
FROM echo_reviews;


-- ────────────────────────────────────────────────────────────
-- SECTION 2: Rating Distribution
-- ────────────────────────────────────────────────────────────

-- Breakdown by each star level with percentage of total
-- Used window function to avoid a subquery for the denominator
SELECT
    rating,
    COUNT(*)                                                  AS review_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)        AS pct_of_total
FROM echo_reviews
WHERE rating IS NOT NULL
GROUP BY rating
ORDER BY rating DESC;


-- ────────────────────────────────────────────────────────────
-- SECTION 3: Device Color Preference
-- ────────────────────────────────────────────────────────────

-- Black vs White — and does color correlate with satisfaction?
-- Spoiler: barely (4.21 vs 4.20), so it's purely a style choice
SELECT
    review_color,
    COUNT(*)                                                  AS review_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)        AS pct_of_total,
    ROUND(AVG(rating), 2)                                     AS avg_rating
FROM echo_reviews
WHERE review_color IS NOT NULL
  AND review_color != ''
GROUP BY review_color
ORDER BY review_count DESC;


-- ────────────────────────────────────────────────────────────
-- SECTION 4: Verified vs. Unverified Buyers
-- ────────────────────────────────────────────────────────────

-- Do verified buyers rate differently than unverified ones?
-- Found a 0.32 star gap — enough to be worth calling out
SELECT
    CASE
        WHEN user_verified = 'Verified Purchase' THEN 'Verified'
        ELSE 'Unverified'
    END                   AS buyer_type,
    COUNT(*)              AS review_count,
    ROUND(AVG(rating), 2) AS avg_rating
FROM echo_reviews
WHERE rating IS NOT NULL
GROUP BY buyer_type
ORDER BY avg_rating DESC;


-- Rating gap between verified and unverified in a single number
SELECT
    ROUND(
        AVG(CASE WHEN user_verified = 'Verified Purchase' THEN rating END) -
        AVG(CASE WHEN user_verified != 'Verified Purchase' THEN rating END),
    2) AS rating_gap
FROM echo_reviews
WHERE rating IS NOT NULL;


-- ────────────────────────────────────────────────────────────
-- SECTION 5: Review Volume Over Time
-- ────────────────────────────────────────────────────────────

-- The date column came in as 'M/D/YYYY' text so I used
-- STR_TO_DATE to parse it properly before grouping by month
SELECT
    DATE_FORMAT(STR_TO_DATE(review_date, '%m/%d/%Y'), '%Y-%m') AS year_month,
    COUNT(*)                                                    AS review_count
FROM echo_reviews
WHERE review_date IS NOT NULL
  AND review_date != ''
GROUP BY year_month
ORDER BY year_month;


-- ────────────────────────────────────────────────────────────
-- SECTION 6: Keyword Analysis
-- ────────────────────────────────────────────────────────────

-- I pulled the top terms from Python first, then used LIKE
-- to count mentions per keyword inside MySQL.
-- LOWER() makes it case-insensitive without a collation change.

SELECT 'love'    AS keyword, COUNT(*) AS mentions FROM echo_reviews WHERE LOWER(review_text) LIKE '%love%'    UNION ALL
SELECT 'echo',                COUNT(*)             FROM echo_reviews WHERE LOWER(review_text) LIKE '%echo%'    UNION ALL
SELECT 'alexa',               COUNT(*)             FROM echo_reviews WHERE LOWER(review_text) LIKE '%alexa%'   UNION ALL
SELECT 'great',               COUNT(*)             FROM echo_reviews WHERE LOWER(review_text) LIKE '%great%'   UNION ALL
SELECT 'music',               COUNT(*)             FROM echo_reviews WHERE LOWER(review_text) LIKE '%music%'   UNION ALL
SELECT 'speaker',             COUNT(*)             FROM echo_reviews WHERE LOWER(review_text) LIKE '%speaker%' UNION ALL
SELECT 'sound',               COUNT(*)             FROM echo_reviews WHERE LOWER(review_text) LIKE '%sound%'   UNION ALL
SELECT 'works',               COUNT(*)             FROM echo_reviews WHERE LOWER(review_text) LIKE '%works%'   UNION ALL
SELECT 'home',                COUNT(*)             FROM echo_reviews WHERE LOWER(review_text) LIKE '%home%'    UNION ALL
SELECT 'weather',             COUNT(*)             FROM echo_reviews WHERE LOWER(review_text) LIKE '%weather%'
ORDER BY mentions DESC;


-- ────────────────────────────────────────────────────────────
-- SECTION 7: Insight Deep Dives
-- ────────────────────────────────────────────────────────────

-- Music mentions broken out by rating
-- Wanted to confirm that music lovers skew positive
SELECT
    rating,
    COUNT(*) AS reviews_mentioning_music
FROM echo_reviews
WHERE LOWER(review_text) LIKE '%music%'
  AND rating IS NOT NULL
GROUP BY rating
ORDER BY rating DESC;


-- Speaker/sound complaints concentrated in 1-2 star reviews
-- This became a key insight: audio quality is the top pain point
SELECT
    rating,
    COUNT(*) AS audio_complaints
FROM echo_reviews
WHERE rating <= 2
  AND (
      LOWER(review_text) LIKE '%speaker%'
   OR LOWER(review_text) LIKE '%sound%'
   OR LOWER(review_text) LIKE '%loud%'
  )
GROUP BY rating
ORDER BY rating;


-- Smart home users in 4-5 star reviews
-- High-rating customers are more likely to mention lights/home automation
SELECT
    rating,
    COUNT(*) AS smart_home_mentions
FROM echo_reviews
WHERE rating >= 4
  AND (
      LOWER(review_text) LIKE '%light%'
   OR LOWER(review_text) LIKE '%smart home%'
   OR LOWER(review_text) LIKE '%thermostat%'
  )
GROUP BY rating
ORDER BY rating DESC;


-- Repeat/multi-unit buyers — do they rate higher?
-- These are customers who mention owning more than one device
SELECT
    COUNT(*)              AS multi_unit_reviews,
    ROUND(AVG(rating), 2) AS avg_rating
FROM echo_reviews
WHERE LOWER(review_text) LIKE '%second%'
   OR LOWER(review_text) LIKE '%bought two%'
   OR LOWER(review_text) LIKE '%bought three%'
   OR LOWER(review_text) LIKE '%another one%'
   OR LOWER(review_text) LIKE '%one more%';


-- ────────────────────────────────────────────────────────────
-- SECTION 8: Review Browser Query
-- Powers the searchable/filterable table in the dashboard.
-- Swap the WHERE values to match whatever the user selects.
-- ────────────────────────────────────────────────────────────

SELECT
    title,
    review_text,
    rating,
    review_color,
    user_verified,
    review_date
FROM echo_reviews
WHERE
    rating          = 5                    -- swap or remove to change filter
    AND review_color     = 'Black'         -- 'Black' or 'White'
    AND user_verified    = 'Verified Purchase'
    AND LOWER(review_text) LIKE '%music%'  -- keyword search
ORDER BY STR_TO_DATE(review_date, '%m/%d/%Y') DESC
LIMIT 100;
