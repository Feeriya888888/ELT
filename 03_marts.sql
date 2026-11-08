-- ============================================================
-- MART-слой: витрины для отчётности.
-- Предагрегаты через AggregatingMergeTree, гибкие срезы - через VIEW.
-- ============================================================
CREATE DATABASE IF NOT EXISTS mart;

-- ---------- DAU: предагрегированный посуточный uniq ----------

CREATE TABLE IF NOT EXISTS mart.daily_active_users (
    day          Date,
    users_state  AggregateFunction(uniq, UInt64)
) ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(day)
ORDER BY day;

INSERT INTO mart.daily_active_users
SELECT
    toDate(event_ts)          AS day,
    uniqState(user_id)        AS users_state
FROM stg.events FINAL
GROUP BY day;

CREATE VIEW IF NOT EXISTS mart.dau AS
SELECT
    day,
    uniqMerge(users_state) AS dau
FROM mart.daily_active_users
GROUP BY day;

-- ---------- Воронка конверсии по дням ----------

CREATE VIEW IF NOT EXISTS mart.funnel AS
SELECT
    toDate(event_ts)                                       AS day,
    uniqIf(user_id, event_type = 'page_view')              AS page_view_users,
    uniqIf(user_id, event_type = 'product_view')           AS product_view_users,
    uniqIf(user_id, event_type = 'add_to_cart')            AS add_to_cart_users,
    uniqIf(user_id, event_type = 'purchase')               AS purchase_users
FROM stg.events FINAL
GROUP BY day;

-- ---------- Выручка по товарам: предагрегат ----------

CREATE TABLE IF NOT EXISTS mart.product_revenue (
    day              Date,
    product_id       UInt32,
    revenue_state    AggregateFunction(sum, UInt64),
    items_state      AggregateFunction(sum, UInt64)
) ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(day)
ORDER BY (day, product_id);

INSERT INTO mart.product_revenue
SELECT
    toDate(o.order_ts)                            AS day,
    i.product_id,
    sumState(i.item_price * i.quantity)           AS revenue_state,
    sumState(toUInt64(i.quantity))                AS items_state
FROM stg.orders o FINAL
INNER JOIN stg.order_items i FINAL USING (order_id)
WHERE o.status != 'cancelled'
GROUP BY day, product_id;

CREATE VIEW IF NOT EXISTS mart.product_revenue_v AS
SELECT
    day,
    product_id,
    sumMerge(revenue_state) AS revenue,
    sumMerge(items_state)   AS items_sold
FROM mart.product_revenue
GROUP BY day, product_id;

-- ---------- Выручка по каналам привлечения ----------

CREATE VIEW IF NOT EXISTS mart.revenue_by_channel AS
SELECT
    u.channel,
    toDate(o.order_ts)                             AS day,
    sum(i.item_price * i.quantity)                 AS revenue,
    count(DISTINCT o.order_id)                     AS orders_cnt
FROM stg.orders o FINAL
INNER JOIN stg.order_items i FINAL USING (order_id)
INNER JOIN stg.users u FINAL USING (user_id)
WHERE o.status != 'cancelled'
GROUP BY channel, day;

-- ---------- Weekly retention по когортам ----------

CREATE VIEW IF NOT EXISTS mart.retention AS
WITH cohorts AS
(
    SELECT user_id, signup_date AS cohort_day
    FROM stg.users FINAL
)
SELECT
    c.cohort_day,
    intDiv(dateDiff('day', c.cohort_day, toDate(e.event_ts)), 7) AS week_n,
    uniq(e.user_id)                                              AS active_users
FROM stg.events e FINAL
INNER JOIN cohorts c USING (user_id)
WHERE dateDiff('day', c.cohort_day, toDate(e.event_ts)) >= 0
GROUP BY cohort_day, week_n;
