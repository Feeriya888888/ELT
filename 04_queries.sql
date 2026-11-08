-- ============================================================
-- Отчётные запросы аналитика - всё идёт поверх витрин.
-- ============================================================

-- 1. DAU за последние 30 дней
SELECT day, dau
FROM mart.dau
WHERE day >= today() - 30
ORDER BY day;

-- 2. Воронка за весь период: конверсия между шагами
SELECT
    sum(page_view_users)     AS viewed,
    sum(product_view_users)  AS viewed_product,
    sum(add_to_cart_users)   AS carted,
    sum(purchase_users)      AS purchased,
    round(purchased / viewed * 100, 2)  AS conv_view_to_purchase_pct,
    round(purchased / carted * 100, 2)  AS conv_cart_to_purchase_pct
FROM mart.funnel;

-- 3. Топ-10 товаров по выручке
SELECT
    p.name,
    p.category,
    sum(r.revenue)    AS revenue,
    sum(r.items_sold) AS items_sold
FROM mart.product_revenue_v r
INNER JOIN stg.products p FINAL USING (product_id)
GROUP BY p.name, p.category
ORDER BY revenue DESC
LIMIT 10;

-- 4. Выручка по каналам привлечения
SELECT
    channel,
    sum(revenue)    AS revenue,
    sum(orders_cnt) AS orders
FROM mart.revenue_by_channel
GROUP BY channel
ORDER BY revenue DESC;

-- 5. Weekly retention: когорты W0..W4
SELECT
    cohort_day,
    maxIf(active_users, week_n = 0) AS w0,
    maxIf(active_users, week_n = 1) AS w1,
    maxIf(active_users, week_n = 2) AS w2,
    maxIf(active_users, week_n = 3) AS w3,
    maxIf(active_users, week_n = 4) AS w4,
    round(maxIf(active_users, week_n = 1) / maxIf(active_users, week_n = 0) * 100, 1) AS week1_ret_pct
FROM mart.retention
GROUP BY cohort_day
ORDER BY cohort_day
LIMIT 20;

-- 6. Проверка объёмов по слоям (наглядно для README/скриншота)
SELECT 'raw.events' AS layer, count() AS rows FROM raw.events
UNION ALL SELECT 'stg.events', count() FROM stg.events
UNION ALL SELECT 'mart.daily_active_users', count() FROM mart.daily_active_users
UNION ALL SELECT 'mart.product_revenue', count() FROM mart.product_revenue;
