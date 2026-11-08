#!/usr/bin/env python3
"""
EXTRACT: имитация исходной системы.

Генерирует CSV-файлы «источника» в data/ - как будто их выгрузила операционная
база или сервис аналитики. Скрипт ничего не знает о ClickHouse: только данные.

Только стандартная библиотека Python, без зависимостей.
"""
import argparse
import csv
import os
import random
from datetime import date, datetime, timedelta

CATEGORIES = {
    "Электроника": ["Смартфон Pro", "Наушники Air", "Ноутбук Slim", "Умные часы Fit", "Планшет Max"],
    "Дом": ["Кофемашина Aroma", "Робот-пылесос Clean", "Увлажнитель Breeze", "Торшер Nordic"],
    "Одежда": ["Куртка Storm", "Футболка Basic", "Джинсы Urban", "Кроссовки Run"],
    "Книги": ["Роман «Волна»", "Справочник SQL", "Биография Кода", "Атлас Миров"],
}
CHANNELS = ["organic", "paid_search", "social", "email"]
CHANNEL_WEIGHTS = [40, 25, 20, 15]


def parse_args():
    p = argparse.ArgumentParser(description="Генерация исходных CSV для ELT-пайплайна")
    p.add_argument("--users", type=int, default=20000)
    p.add_argument("--products", type=int, default=200)
    p.add_argument("--days", type=int, default=60)
    p.add_argument("--events", type=int, default=2_000_000)
    p.add_argument("--out-dir", default="data")
    p.add_argument("--seed", type=int, default=42)
    return p.parse_args()


def ts(d: date, rnd: random.Random) -> str:
    return datetime(d.year, d.month, d.day, rnd.randint(0, 23), rnd.randint(0, 59), rnd.randint(0, 59)).strftime("%Y-%m-%d %H:%M:%S")


def main():
    args = parse_args()
    rnd = random.Random(args.seed)
    os.makedirs(args.out_dir, exist_ok=True)

    today = date.today()
    start = today - timedelta(days=args.days - 1)

    # ---- users
    with open(os.path.join(args.out_dir, "users.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["user_id", "signup_date", "channel"])
        for uid in range(1, args.users + 1):
            signup = start + timedelta(days=rnd.randint(0, args.days - 1))
            w.writerow([uid, signup.isoformat(), rnd.choices(CHANNELS, CHANNEL_WEIGHTS)[0]])

    # ---- products
    categories = list(CATEGORIES)
    with open(os.path.join(args.out_dir, "products.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["product_id", "name", "category", "price"])
        for pid in range(1, args.products + 1):
            cat = rnd.choice(categories)
            w.writerow([pid, f"{rnd.choice(CATEGORIES[cat])} #{pid}", cat, rnd.choice([299, 499, 790, 1290, 1990, 3490, 5990])])

    prices = {pid: rnd.choice([299, 499, 790, 1290, 1990, 3490, 5990]) for pid in range(1, args.products + 1)}

    # ---- events + orders: эмулируем воронку и затухание активности
    events, orders, items = [], [], []
    eid = 0
    order_id = 0
    for uid in range(1, args.users + 1):
        signup = start + timedelta(days=rnd.randint(0, args.days - 1))
        sessions = min(max(1 + int(rnd.expovariate(1 / 2.5)), 1), args.days)
        for s in range(sessions):
            day = signup + timedelta(days=int(s * rnd.uniform(0.8, 2.2)))
            if day > today:
                continue
            eid += 1
            events.append([eid, uid, "page_view", ts(day, rnd), "/home"])
            eid += 1
            events.append([eid, uid, "product_view", ts(day, rnd), f"/product/{rnd.randint(1, args.products)}"])
            if rnd.random() < 0.35:
                eid += 1
                events.append([eid, uid, "add_to_cart", ts(day, rnd), "/cart"])
                if rnd.random() < 0.45:
                    order_id += 1
                    order_ts = ts(day, rnd)
                    age = (today - day).days
                    status = "cancelled" if rnd.random() < 0.1 else ("delivered" if age > 7 else "paid")
                    orders.append([order_id, uid, status, order_ts])
                    eid += 1
                    events.append([eid, uid, "purchase", order_ts, "/checkout"])
                    for _ in range(rnd.randint(1, 3)):
                        pid = rnd.randint(1, args.products)
                        qty = rnd.randint(1, 3)
                        items.append([order_id, pid, qty, prices[pid]])

            if len(events) >= args.events:
                break
        if len(events) >= args.events:
            break

    def dump(name, header, rows):
        with open(os.path.join(args.out_dir, name), "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(header)
            w.writerows(rows)

    dump("events.csv", ["event_id", "user_id", "event_type", "event_ts", "page_url"], events)
    dump("orders.csv", ["order_id", "user_id", "status", "order_ts"], orders)
    dump("order_items.csv", ["order_id", "product_id", "quantity", "item_price"], items)

    print("EXTRACT готов. Файлы в", args.out_dir)
    for name in ("users.csv", "products.csv", "events.csv", "orders.csv", "order_items.csv"):
        path = os.path.join(args.out_dir, name)
        print(f"  {name:18s} {os.path.getsize(path) / 1024:8.1f} KB")


if __name__ == "__main__":
    main()
