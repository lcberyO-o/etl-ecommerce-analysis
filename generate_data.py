# -*- coding: utf-8 -*-
"""
生成一套「模拟电商订单」数据，用于个人 ETL / 数据分析项目。

说明：
- 数据是脚本随机生成的，不是真实业务数据。
- 脚本注入了脏数据（重复、空值、异常值、未来日期、金额不一致等），
  用于验证下游的清洗逻辑，清洗口径见 sql/02_clean_view.sql。
- 运行：python generate_data.py
- 输出：同目录下 data/ 里的 5 个 CSV。
"""

from pathlib import Path

import numpy as np
import pandas as pd

SEED = 20261109
rng = np.random.default_rng(SEED)

BASE = Path(__file__).resolve().parent
DATA = BASE / "data"
DATA.mkdir(exist_ok=True)

N_USERS = 50_000
N_PRODUCTS = 800
N_ORDERS = 100_000
START = pd.Timestamp("2025-01-01")
END = pd.Timestamp("2026-10-31")

# ---------------------------------------------------------------- 渠道
channels = pd.DataFrame(
    {
        "channel_id": np.arange(1, 7),
        "channel_name": ["自然流量", "搜索广告", "信息流", "社交裂变", "地推", "老客推荐"],
    }
)
CHANNEL_P = np.array([0.30, 0.20, 0.22, 0.12, 0.08, 0.08])

# ---------------------------------------------------------------- 用户
cities = ["南京", "苏州", "无锡", "常州", "扬州", "徐州", "杭州", "上海", "北京", "广州"]
CITY_P = np.array([0.30, 0.14, 0.10, 0.08, 0.06, 0.06, 0.08, 0.08, 0.05, 0.05])

reg_start = pd.Timestamp("2024-07-01")
reg_end = pd.Timestamp("2026-09-30")
reg_days = (reg_end - reg_start).days

users = pd.DataFrame(
    {
        "user_id": np.arange(1, N_USERS + 1),
        "register_date": reg_start + pd.to_timedelta(rng.integers(0, reg_days, N_USERS), unit="D"),
        "city": rng.choice(cities, N_USERS, p=CITY_P),
        "age": rng.integers(18, 46, N_USERS),
        "gender": rng.choice(["男", "女", "未知"], N_USERS, p=[0.46, 0.48, 0.06]),
        "channel_id": rng.choice(channels["channel_id"], N_USERS, p=CHANNEL_P),
    }
)

# ---------------------------------------------------------------- 商品
cat_specs = {
    "手机数码": (600, 6000, 0.05),
    "电脑办公": (800, 8000, 0.04),
    "家用电器": (200, 4000, 0.05),
    "服饰鞋包": (50, 800, 0.16),
    "食品生鲜": (10, 200, 0.05),
    "美妆个护": (30, 600, 0.07),
    "母婴玩具": (20, 500, 0.04),
    "运动户外": (50, 1500, 0.05),
}
cats = list(cat_specs)
CAT_P = np.array([0.18, 0.10, 0.10, 0.22, 0.18, 0.10, 0.06, 0.06])

prod_rows = []
for pid in range(1, N_PRODUCTS + 1):
    c = rng.choice(cats, p=CAT_P)
    lo, hi, _ = cat_specs[c]
    price = float(np.exp(rng.uniform(np.log(lo), np.log(hi))))
    cost = price * rng.uniform(0.55, 0.80)
    prod_rows.append((pid, c, round(price, 2), round(cost, 2)))
products = pd.DataFrame(prod_rows, columns=["product_id", "category", "price", "cost"])

# 不同渠道的品类偏好，用来制造「渠道客单价/退款率」差异
base_w = CAT_P.copy()
cat_w = {
    1: base_w,
    2: base_w,
    3: np.array([0.30, 0.12, 0.10, 0.16, 0.10, 0.14, 0.03, 0.05]),
    4: np.array([0.15, 0.08, 0.08, 0.28, 0.20, 0.09, 0.06, 0.06]),
    5: np.array([0.10, 0.06, 0.12, 0.20, 0.24, 0.10, 0.10, 0.08]),
    6: np.array([0.14, 0.08, 0.08, 0.20, 0.24, 0.08, 0.12, 0.06]),
}
for k in cat_w:
    cat_w[k] = cat_w[k] / cat_w[k].sum()

# ---------------------------------------------------------------- 订单日期
days = pd.date_range(START, END, freq="D")
day_w = np.ones(len(days))
for i, d in enumerate(days):
    if d.month == 6:
        day_w[i] *= 1.6      # 618
    if d.month == 11:
        day_w[i] *= 2.0      # 双 11
    if d.month == 12:
        day_w[i] *= 1.3
day_w = day_w / day_w.sum()
order_dates = pd.to_datetime(rng.choice(days.values, N_ORDERS, p=day_w))

# 用户抽样：老客推荐渠道的用户下单更多（复购率高）
u_w = np.ones(N_USERS)
u_ch = users["channel_id"].to_numpy()
u_w[u_ch == 6] = 3.0
u_w[u_ch == 1] = 1.15
u_w[u_ch == 3] = 0.75
u_w = u_w / u_w.sum()

user_idx = rng.choice(N_USERS, N_ORDERS, p=u_w)
reg = users["register_date"].to_numpy()
bad = order_dates.to_numpy() < reg[user_idx]
while bad.any():
    n = int(bad.sum())
    user_idx[bad] = rng.choice(N_USERS, n, p=u_w)
    bad = order_dates.to_numpy() < reg[user_idx]

user_ch = users["channel_id"].to_numpy()[user_idx]
order_ch = user_ch.copy()
mask = rng.random(N_ORDERS) < 0.15
order_ch[mask] = rng.choice(channels["channel_id"], int(mask.sum()), p=CHANNEL_P)

# ---------------------------------------------------------------- 订单明细
prod_by_cat = {
    c: products.loc[products["category"] == c, "product_id"].to_numpy() for c in cats
}
prod_price = products.set_index("product_id")["price"].to_dict()

n_items = rng.integers(1, 4, N_ORDERS)
mask_info = order_ch == 3
n_items[mask_info] = rng.integers(2, 6, int(mask_info.sum()))

item_rows = []
for i in range(N_ORDERS):
    k = int(n_items[i])
    chosen = rng.choice(cats, size=k, p=cat_w[int(order_ch[i])])
    for c in chosen:
        pid = int(rng.choice(prod_by_cat[c]))
        qty = int(rng.integers(1, 4))
        unit = round(prod_price[pid] * rng.uniform(0.9, 1.1), 2)
        item_rows.append((i + 1, pid, qty, unit))

items = pd.DataFrame(item_rows, columns=["order_id", "product_id", "quantity", "unit_price"])
items["line_amount"] = (items["quantity"] * items["unit_price"]).round(2)
order_total = items.groupby("order_id")["line_amount"].sum().round(2)

orders = pd.DataFrame(
    {
        "order_id": np.arange(1, N_ORDERS + 1),
        "user_id": users["user_id"].to_numpy()[user_idx],
        "order_date": order_dates,
        "channel_id": order_ch,
        "total_amount": order_total.reindex(np.arange(1, N_ORDERS + 1)).to_numpy(),
    }
)

# ---------------------------------------------------------------- 订单状态
items_cat = items.merge(products[["product_id", "category"]], on="product_id", how="left")
first_cat = items_cat.groupby("order_id")["category"].first()
refund_map = first_cat.map({c: cat_specs[c][2] for c in cats})
p_refund = orders["order_id"].map(refund_map).fillna(0.06).to_numpy() + 0.01
p_cancel = np.full(N_ORDERS, 0.05)
p_paid = 1 - p_refund - p_cancel
r = rng.random(N_ORDERS)
orders["status"] = np.where(
    r < p_paid, "paid", np.where(r < p_paid + p_refund, "refunded", "cancelled")
)

# ---------------------------------------------------------------- 故意埋脏数据
orders = pd.concat([orders, orders.sample(600, random_state=SEED)], ignore_index=True)

def dirty_rows(df, n, col, value_fn):
    idx = rng.choice(df.index, n, replace=False)
    for i in idx:
        df.at[i, col] = value_fn()

dirty_rows(orders, 300, "user_id", lambda: np.nan)
idx = rng.choice(orders.index, 150, replace=False)
for i in idx:
    orders.at[i, "order_date"] = pd.Timestamp("2027-01-01") + pd.to_timedelta(
        int(rng.integers(0, 90)), unit="D"
    )
dirty_rows(orders, 200, "status", lambda: np.nan)
dirty_rows(orders, 120, "channel_id", lambda: 99)
dirty_rows(orders, 200, "total_amount", lambda: np.nan)
dirty_rows(orders, 80, "total_amount", lambda: -round(float(rng.uniform(10, 500)), 2))

idx = rng.choice(items.index, 400, replace=False)
items.loc[idx, "quantity"] = -items.loc[idx, "quantity"]
dirty_rows(items, 100, "unit_price", lambda: np.nan)

dirty_rows(users, 150, "city", lambda: " 南京 ")
dirty_rows(users, 50, "age", lambda: 999)
dirty_rows(users, 100, "gender", lambda: np.nan)

dirty_rows(products, 20, "price", lambda: np.nan)
dirty_rows(products, 10, "price", lambda: -round(float(rng.uniform(10, 200)), 2))

# ---------------------------------------------------------------- 导出
orders_out = orders.copy()
orders_out["order_date"] = pd.to_datetime(orders_out["order_date"]).dt.strftime("%Y-%m-%d")

users_out = users.copy()
users_out["register_date"] = pd.to_datetime(users_out["register_date"]).dt.strftime("%Y-%m-%d")

orders_out.to_csv(DATA / "orders.csv", index=False, encoding="utf-8")
items.to_csv(DATA / "order_items.csv", index=False, encoding="utf-8")
users_out.to_csv(DATA / "users.csv", index=False, encoding="utf-8")
products.to_csv(DATA / "products.csv", index=False, encoding="utf-8")
channels.to_csv(DATA / "channels.csv", index=False, encoding="utf-8")

print("生成完成：")
print(f"  users.csv        {len(users_out):>8,} 行")
print(f"  products.csv     {len(products):>8,} 行")
print(f"  channels.csv     {len(channels):>8,} 行")
print(f"  orders.csv       {len(orders_out):>8,} 行")
print(f"  order_items.csv  {len(items):>8,} 行")
print(f"输出目录：{DATA}")
