# -*- coding: utf-8 -*-
"""把 CSV 复制到 ASCII 临时目录，修正整数列，并把空值改成 MySQL 的 NULL（\\N）。"""

import csv
import tempfile
from pathlib import Path

SRC = Path(__file__).resolve().parent / "data"
DST = Path(tempfile.gettempdir()) / "xiaomi_csv"
DST.mkdir(parents=True, exist_ok=True)

# 允许 NULL 的列：空字符串转成 \N
NULL_COLS = {
    "channels.csv": set(),
    "users.csv": {"gender"},
    "products.csv": {"price"},
    "orders.csv": {"user_id", "total_amount", "status"},
    "order_items.csv": {"unit_price"},
}

# 整数列：pandas 遇到空值会把整列写成 15954.0，这里转回 15954
INT_COLS = {
    "channels.csv": {"channel_id"},
    "users.csv": {"user_id", "age", "channel_id"},
    "products.csv": {"product_id"},
    "orders.csv": {"order_id", "user_id", "channel_id"},
    "order_items.csv": {"order_id", "product_id", "quantity"},
}

for name, null_cols in NULL_COLS.items():
    with (SRC / name).open("r", encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))

    header = rows[0]
    idx = {c: i for i, c in enumerate(header)}

    for row in rows[1:]:
        for col in null_cols:
            i = idx[col]
            if row[i] == "":
                row[i] = "\\N"

        for col in INT_COLS[name]:
            i = idx[col]
            value = row[i]
            if value == "":
                row[i] = "\\N"
            elif value != "\\N":
                row[i] = str(int(float(value)))

    out = DST / name
    with out.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)

    print(f"{name}: {len(rows) - 1} data rows -> {out}")
