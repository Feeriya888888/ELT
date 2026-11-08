#!/usr/bin/env python3
"""
LOAD: загружает сырые CSV «как есть» в raw-слой ClickHouse.

Никакой трансформации: строки уходят в raw.* один в один, как в источнике.
Только стандартная библиотека Python, без зависимостей.
"""
import argparse
import os
import sys
import urllib.parse
import urllib.request

MAPPING = [
    ("users.csv",       "raw.users",       "user_id, signup_date, channel"),
    ("products.csv",    "raw.products",    "product_id, name, category, price"),
    ("events.csv",      "raw.events",      "event_id, user_id, event_type, event_ts, page_url"),
    ("orders.csv",      "raw.orders",      "order_id, user_id, status, order_ts"),
    ("order_items.csv", "raw.order_items", "order_id, product_id, quantity, item_price"),
]


def parse_args():
    p = argparse.ArgumentParser(description="Загрузка CSV в raw-слой ClickHouse")
    p.add_argument("--host", default="localhost")
    p.add_argument("--port", type=int, default=8123)
    p.add_argument("--user", default="analyst")
    p.add_argument("--password", default=os.environ.get("CLICKHOUSE_PASSWORD", "analyst_pass"))
    p.add_argument("--data-dir", default="data")
    return p.parse_args()


def main():
    args = parse_args()
    base = f"http://{args.host}:{args.port}/?user={args.user}&password={args.password}"
    for fname, table, cols in MAPPING:
        path = os.path.join(args.data_dir, fname)
        if not os.path.exists(path):
            print(f"  {fname}: файл не найден, пропускаю (сначала запустите extract.py)")
            continue
        query = f"INSERT INTO {table} ({cols}) FORMAT CSV"
        req = urllib.request.Request(
            base + "&query=" + urllib.parse.quote_plus(query),
            data=open(path, "rb").read(),
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=600) as resp:
            body = resp.read().decode()
            if resp.status != 200:
                sys.exit(f"Ошибка загрузки {fname}: {body}")
            print(f"  {fname:18s} -> {table:18s} OK")


if __name__ == "__main__":
    main()
