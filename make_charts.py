# -*- coding: utf-8 -*-
"""用 results/ 下的 SQL 结果画 3 张图（Pillow 绘制，不依赖 matplotlib）。

运行：python make_charts.py
输出：charts/channel_gmv_aov.png、charts/monthly_gmv.png、charts/category_refund.png
"""

import csv
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BASE = Path(__file__).resolve().parent
RES = BASE / "results"
OUT = BASE / "charts"

S = 2                 # 超采样倍数，最后缩回一半做抗锯齿
W, H = 1200, 720      # 成图尺寸（px）
NAVY = (31, 58, 95)
ACCENT = (46, 110, 142)
ORANGE = (196, 98, 59)
GRID = (226, 232, 238)
AXIS = (196, 204, 212)
TEXT = (51, 51, 51)
MUTED = (120, 128, 136)

REG = r"C:\Windows\Fonts\msyh.ttc"
BOLD = r"C:\Windows\Fonts\msyhbd.ttc"


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else REG, int(size * S))


def load(name):
    with (RES / f"{name}.tsv").open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def num(v):
    return 0.0 if v in ("NULL", "", None) else float(v)


def yi(v):
    """元 -> 亿元"""
    return v / 1e8


class Chart:
    def __init__(self, title, subtitle):
        self.img = Image.new("RGB", (W * S, H * S), "white")
        self.d = ImageDraw.Draw(self.img)
        self.d.text((64 * S, 38 * S), title, font=font(27, True), fill=NAVY, anchor="lm")
        self.d.text((64 * S, 76 * S), subtitle, font=font(14), fill=MUTED, anchor="lm")
        # 绘图区
        self.x0, self.y0, self.x1, self.y1 = 120, 128, 1010, 606

    def line(self, p0, p1, fill=GRID, width=1.4, dash=None):
        if not dash:
            self.d.line([p0, p1], fill=fill, width=max(1, int(width * S)))
            return
        (x0, y0), (x1, y1) = p0, p1
        length = math.hypot(x1 - x0, y1 - y0)
        if length == 0:
            return
        ux, uy = (x1 - x0) / length, (y1 - y0) / length
        t = 0.0
        step = dash
        while t < length:
            a = (x0 + ux * t, y0 + uy * t)
            e = min(t + step * 0.55, length)
            b = (x0 + ux * e, y0 + uy * e)
            self.d.line([a, b], fill=fill, width=max(1, int(width * S)))
            t += step

    def text(self, xy, s, size=14, color=TEXT, anchor="lm", bold=False, badge=False):
        x, y = xy[0] * S, xy[1] * S
        if badge:
            box = self.d.textbbox((x, y), s, font=font(size, bold), anchor=anchor)
            pad = 3 * S
            self.d.rounded_rectangle(
                [box[0] - pad, box[1] - pad * 0.6, box[2] + pad, box[3] + pad * 0.6],
                radius=4 * S,
                fill=(255, 255, 255),
            )
        self.d.text((x, y), s, font=font(size, bold), fill=color, anchor=anchor)

    def save(self, name):
        OUT.mkdir(exist_ok=True)
        self.img.resize((W, H), Image.LANCZOS).save(OUT / name)
        print(OUT / name)


def axis(step, needed):
    """给定刻度步长，返回能覆盖 needed 的坐标轴上限"""
    return step * math.ceil(needed / step - 1e-9)


# ------------------------------------------------------------------ 图 1
def chart_channel(ch):
    c = Chart(
        "渠道 GMV 与客单价",
        "数据：模拟电商订单（2025.01–2026.10，status = paid）    单位：GMV 亿元 / 客单价 元",
    )
    ch = sorted(ch, key=lambda r: num(r["gmv"]), reverse=True)
    labels = [r["channel_name"] for r in ch]
    gmv = [yi(num(r["gmv"])) for r in ch]
    aov = [num(r["aov"]) for r in ch]

    g_step, a_step = 0.4, 3000
    g_max = axis(g_step, max(gmv) * 1.14)
    a_max = axis(a_step, max(aov) * 1.2)

    def gx(i):
        return c.x0 + (i + 0.5) * (c.x1 - c.x0) / len(ch)

    def gy(v):
        return c.y1 - v / g_max * (c.y1 - c.y0)

    def ay(v):
        return c.y1 - v / a_max * (c.y1 - c.y0)

    # 横向网格 + 左右刻度
    n = int(round(g_max / g_step))
    for k in range(n + 1):
        v = g_step * k
        y = gy(v)
        c.line((c.x0, y), (c.x1, y), AXIS if k == 0 else GRID)
        c.text((c.x0 - 12, y), f"{v:.1f}", 13, MUTED, anchor="rm")
        c.text((c.x1 + 12, y), f"{a_step * k:,.0f}", 13, MUTED, anchor="lm")

    # 柱：GMV（数值写在柱内，折线贴在柱顶时下移，避免被线穿过）
    bw = (c.x1 - c.x0) / len(ch) * 0.46
    for i, v in enumerate(gmv):
        x = gx(i)
        c.d.rectangle([(x - bw / 2) * S, gy(v) * S, (x + bw / 2) * S, c.y1 * S], fill=ACCENT)
        near_line = abs(ay(aov[i]) - gy(v)) < 30
        c.text((x, gy(v) + (44 if near_line else 17)), f"{v:.2f}", 13, (255, 255, 255), anchor="mm", bold=True)

    # 折线：客单价
    pts = [(gx(i), ay(v)) for i, v in enumerate(aov)]
    c.d.line([(x * S, y * S) for x, y in pts], fill=ORANGE, width=int(2.6 * S), joint="curve")
    for (x, y) in pts:
        r = 4.5
        c.d.ellipse(
            [(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S],
            fill="white",
            outline=ORANGE,
            width=int(2.2 * S),
        )

    # 类目 + 客单价数值行（放在 x 轴下方，避免和柱内数值打架）
    for i, name in enumerate(labels):
        c.text((gx(i), c.y1 + 28), name, 14, TEXT, anchor="mm")
    c.text((c.x0 - 14, c.y1 + 58), "客单价", 12.5, MUTED, anchor="rm")
    for i, v in enumerate(aov):
        c.text((gx(i), c.y1 + 58), f"{v:,.0f}", 13, ORANGE, anchor="mm", bold=True)

    # 图例
    c.d.rectangle([64 * S, 97 * S, 78 * S, 107 * S], fill=ACCENT)
    c.text((86, 102), "GMV（左轴，亿元）", 13, TEXT)
    ln_x = 86 + 200
    c.d.line([ln_x * S, 102 * S, (ln_x + 18) * S, 102 * S], fill=ORANGE, width=int(2.6 * S))
    c.text((ln_x + 26, 102), "客单价（右轴，元）", 13, TEXT)

    c.save("channel_gmv_aov.png")


# ------------------------------------------------------------------ 图 2
def chart_monthly(rows):
    c = Chart(
        "月度 GMV 趋势",
        "数据：模拟电商订单（status = paid）    单位：亿元    标注 618 / 双 11 大促月",
    )
    labels = [r["ym"] for r in rows]
    gmv = [yi(num(r["gmv"])) for r in rows]

    y_step = 0.1
    y_max = axis(y_step, max(gmv) * 1.15)

    def gx(i):
        return c.x0 + (i + 0.5) * (c.x1 - c.x0) / len(rows)

    def gy(v):
        return c.y1 - v / y_max * (c.y1 - c.y0)

    n = int(round(y_max / y_step))
    for k in range(n + 1):
        v = y_step * k
        y = gy(v)
        c.line((c.x0, y), (c.x1, y), AXIS if k == 0 else GRID)
        c.text((c.x0 - 12, y), f"{v:.1f}", 13, MUTED, anchor="rm")

    # 折线下浅色填充
    pts = [(gx(i), gy(v)) for i, v in enumerate(gmv)]
    c.d.polygon(
        [(pts[0][0] * S, c.y1 * S)] + [(x * S, y * S) for x, y in pts] + [(pts[-1][0] * S, c.y1 * S)],
        fill=(233, 240, 245),
    )
    c.d.line([(x * S, y * S) for x, y in pts], fill=ACCENT, width=int(2.6 * S), joint="curve")
    for (x, y) in pts:
        r = 3.6
        c.d.ellipse(
            [(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S],
            fill="white",
            outline=ACCENT,
            width=int(2 * S),
        )

    # 大促标注（标在峰值上方）
    peaks = {"2025-06": "618", "2025-11": "双 11", "2026-06": "618"}
    for i, ym in enumerate(labels):
        if ym in peaks:
            x, y = pts[i]
            c.text((x, y - 22), f"{peaks[ym]}  {gmv[i]:.2f}", 13, ORANGE, anchor="mm", bold=True, badge=True)

    # x 轴：每 3 个月一个标签
    for i, ym in enumerate(labels):
        if i % 3 == 0 or i == len(labels) - 1:
            c.text((gx(i), c.y1 + 28), ym, 12.5, TEXT, anchor="mm")

    c.save("monthly_gmv.png")


# ------------------------------------------------------------------ 图 3
def chart_refund(rows):
    c = Chart(
        "品类退款率（Top3 深色）",
        "数据：模拟电商订单    口径：退款订单数 / 支付订单数（按 order_id 去重），支付订单 < 100 的品类不参与",
    )
    rows = sorted(rows, key=lambda r: num(r["refund_rate"]), reverse=True)
    x_step = 0.05
    x_max = axis(x_step, max(num(r["refund_rate"]) for r in rows) * 1.12)

    top, bottom = c.y0 + 4, c.y1 - 6
    slot = (bottom - top) / len(rows)
    bar_h = slot * 0.56

    n = int(round(x_max / x_step))
    for k in range(n + 1):
        v = x_step * k
        x = c.x0 + v / x_max * (c.x1 - c.x0)
        c.line((x, c.y0), (x, c.y1), AXIS if k == 0 else GRID)
        c.text((x, c.y1 + 28), f"{v * 100:.0f}%", 13, MUTED, anchor="mm")

    for i, r in enumerate(rows):
        rate = num(r["refund_rate"])
        y = top + (i + 0.5) * slot
        w = rate / x_max * (c.x1 - c.x0)
        top3 = i < 3
        c.d.rectangle(
            [c.x0 * S, (y - bar_h / 2) * S, (c.x0 + w) * S, (y + bar_h / 2) * S],
            fill=ORANGE if top3 else ACCENT,
        )
        c.text((c.x0 - 14, y), r["main_category"], 14.5, TEXT, anchor="rm")
        c.text(
            (c.x0 + w + 12, y),
            f"{rate * 100:.1f}%",
            13.5,
            ORANGE if top3 else NAVY,
            anchor="lm",
            bold=top3,
        )

    c.save("category_refund.png")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    chart_channel(load("03_channel"))
    chart_monthly(load("05_monthly"))
    chart_refund(load("06_refund"))
