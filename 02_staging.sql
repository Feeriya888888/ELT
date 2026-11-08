-- ============================================================
-- STAGING-слой: типизация, валидация, дедупликация - всё SQL-ом.
-- ReplacingMergeTree(loaded_at) делает повторную загрузку идемпотентной:
-- дубликаты схлопываются при слияниях, в запросах читаем через FINAL.
-- ============================================================
CREATE DATABASE IF NOT EXISTS stg;

CREATE TABLE IF NOT EXISTS stg.users (
    user_id      UInt64,
    signup_date  Date,
    channel      LowCardinality(String),
    loaded_at    DateTime
) ENGINE = ReplacingMergeTree(loaded_at)
ORDER BY user_id;

INSERT INTO stg.users
SELECT
    toUInt64(user_id)          AS user_id,
    toDate(signup_date)        AS signup_date,
    channel,
    max(loaded_at)             AS loaded_at
FROM raw.users
WHERE isNumeric(user_id)
  AND toDateOrNull(signup_date) IS NOT NULL
GROUP BY user_id, signup_date, channel;

CREATE TABLE IF NOT EXISTS stg.products (
    product_id   UInt32,
    name         String,
    category     LowCardinality(String),
    price        UInt64,
    loaded_at    DateTime
) ENGINE = ReplacingMergeTree(loaded_at)
ORDER BY product_id;

INSERT INTO stg.products
SELECT
    toUInt32(product_id),
    name,
    category,
    toUInt64(price),
    max(loaded_at)
FROM raw.products
WHERE isNumeric(product_id) AND isNumeric(price)
GROUP BY product_id, name, category, price;

CREATE TABLE IF NOT EXISTS stg.events (
    event_id     UInt64,
    user_id      UInt64,
    event_type   Enum8('page_view' = 1, 'product_view' = 2, 'add_to_cart' = 3, 'purchase' = 4),
    event_ts     DateTime,
    page_url     String,
    loaded_at    DateTime
) ENGINE = ReplacingMergeTree(loaded_at)
ORDER BY event_id;

INSERT INTO stg.events
SELECT
    toUInt64(event_id),
    toUInt64(user_id),
    event_type,
    parseDateTimeBestEffort(event_ts),
    page_url,
    max(loaded_at)
FROM raw.events
WHERE isNumeric(event_id)
  AND isNumeric(user_id)
  AND event_type IN ('page_view', 'product_view', 'add_to_cart', 'purchase')
  AND parseDateTimeBestEffortOrNull(event_ts) IS NOT NULL
GROUP BY event_id, user_id, event_type, event_ts, page_url;

CREATE TABLE IF NOT EXISTS stg.orders (
    order_id     UInt64,
    user_id      UInt64,
    status       Enum8('created' = 1, 'paid' = 2, 'shipped' = 3, 'delivered' = 4, 'cancelled' = 5),
    order_ts     DateTime,
    loaded_at    DateTime
) ENGINE = ReplacingMergeTree(loaded_at)
ORDER BY order_id;

INSERT INTO stg.orders
SELECT
    toUInt64(order_id),
    toUInt64(user_id),
    status,
    parseDateTimeBestEffort(order_ts),
    max(loaded_at)
FROM raw.orders
WHERE isNumeric(order_id)
  AND isNumeric(user_id)
  AND status IN ('created', 'paid', 'shipped', 'delivered', 'cancelled')
  AND parseDateTimeBestEffortOrNull(order_ts) IS NOT NULL
GROUP BY order_id, user_id, status, order_ts;

CREATE TABLE IF NOT EXISTS stg.order_items (
    order_id     UInt64,
    product_id   UInt32,
    quantity     UInt8,
    item_price   UInt64,
    loaded_at    DateTime
) ENGINE = ReplacingMergeTree(loaded_at)
ORDER BY (order_id, product_id);

INSERT INTO stg.order_items
SELECT
    toUInt64(order_id),
    toUInt32(product_id),
    toUInt8(quantity),
    toUInt64(item_price),
    max(loaded_at)
FROM raw.order_items
WHERE isNumeric(order_id) AND isNumeric(product_id)
  AND isNumeric(quantity) AND isNumeric(item_price)
GROUP BY order_id, product_id, quantity, item_price;

-- TTL: staging храним 24 месяца
ALTER TABLE stg.events MODIFY TTL event_ts + INTERVAL 24 MONTH;
ALTER TABLE stg.orders MODIFY TTL order_ts + INTERVAL 24 MONTH;
