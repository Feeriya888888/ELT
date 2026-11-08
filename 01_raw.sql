-- ============================================================
-- RAW-слой: данные загружаются «как есть», без типизации.
-- Все поля String - источник мог прислать мусор, это нормально.
-- ============================================================
CREATE DATABASE IF NOT EXISTS raw;

CREATE TABLE IF NOT EXISTS raw.users (
    user_id      String,
    signup_date  String,
    channel      String,
    loaded_at    DateTime DEFAULT now()
) ENGINE = MergeTree
ORDER BY user_id;

CREATE TABLE IF NOT EXISTS raw.products (
    product_id   String,
    name         String,
    category     String,
    price        String,
    loaded_at    DateTime DEFAULT now()
) ENGINE = MergeTree
ORDER BY product_id;

CREATE TABLE IF NOT EXISTS raw.events (
    event_id     String,
    user_id      String,
    event_type   String,
    event_ts     String,
    page_url     String,
    loaded_at    DateTime DEFAULT now()
) ENGINE = MergeTree
ORDER BY event_id;

CREATE TABLE IF NOT EXISTS raw.orders (
    order_id     String,
    user_id      String,
    status       String,
    order_ts     String,
    loaded_at    DateTime DEFAULT now()
) ENGINE = MergeTree
ORDER BY order_id;

CREATE TABLE IF NOT EXISTS raw.order_items (
    order_id     String,
    product_id   String,
    quantity     String,
    item_price   String,
    loaded_at    DateTime DEFAULT now()
) ENGINE = MergeTree
ORDER BY (order_id, product_id);
