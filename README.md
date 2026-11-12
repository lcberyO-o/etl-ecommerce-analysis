# 模拟电商订单 ETL 与分析

个人项目：用 Python 按真实电商表结构模拟一套订单数据（5 张表、约 37 万行），在 MySQL 8.0 上完成
「建表 → 导入 → 数据质量盘点 → 清洗 → 指标计算 → 可视化 → 结论」的完整链路。

> 数据由脚本生成，不是真实业务数据。项目重点是方法：口径怎么定、脏数据怎么处理、指标怎么用 SQL 算。

## 产出

| 内容 | 位置 |
|---|---|
| SQL 脚本（11 个任务） | `sql/01_quality.sql` … `sql/11_channel_category.sql` |
| 每个任务的执行结果 | `results/*.tsv`（UTF-8 带 BOM、Tab 分隔，列说明见 `results/README.md`） |
| 图表（3 张） | `charts/*.png`，由 `make_charts.py` 从 `results/` 生成 |
| 分析与结论 | `analysis.md` |

主要结论：信息流渠道 GMV 1.24 亿、客单价 9,197 元均最高，但复购率仅 51.8%（六渠道最低）；
服饰鞋包退款率 17.9%，约为其他品类的 2 倍；618 / 双 11 当月 GMV 环比 +57% / +92%，次月回落 33%–38%。

## 目录结构

```
├── data/                     # 生成的 CSV（约 13 MB，git 忽略，可重新生成）
├── sql/
│   ├── 01_quality.sql        # 数据质量盘点（15 类异常）
│   ├── 02_clean_view.sql     # 清洗视图 v_orders_clean
│   ├── 03_channel.sql        # 渠道 GMV / 客单价
│   ├── 04_repeat.sql         # 渠道复购率
│   ├── 05_monthly.sql        # 月度 GMV 与环比
│   ├── 06_refund.sql         # 品类退款率
│   ├── 07_top_products.sql   # 品类 GMV Top3 商品
│   ├── 08_cohort_30d.sql     # 首单后 30 天复购率
│   ├── 09_latest_order.sql   # 每个用户最近一单
│   ├── 10_consecutive_3m.sql # 连续 3 个月下单的用户
│   └── 11_channel_category.sql # 渠道 × 品类交叉
├── results/                  # 上述脚本的输出（TSV，可直接用 Excel 打开）
├── charts/                   # 3 张图
├── analysis.md               # 结论、口径说明、建议
├── create_tables.sql         # 建库建表
├── generate_data.py          # 生成模拟数据
├── prepare_load.py           # 导入前处理：空值转 NULL、整数列修正
├── load_all.sql              # LOAD DATA 批量导入
├── 一键导入.bat              # 双击执行 load_all.sql
└── make_charts.py            # 用 results/ 画图（Pillow）
```

## 数据模型

| 表 | 行数 | 说明 |
|---|---:|---|
| `users` | 50,000 | 用户：注册日期、城市、年龄、性别、注册渠道 |
| `products` | 800 | 商品：8 个品类、售价、成本 |
| `channels` | 6 | 渠道字典：自然流量 / 搜索广告 / 信息流 / 社交裂变 / 地推 / 老客推荐 |
| `orders` | 100,600 | 订单：用户、日期、渠道、金额、状态（paid / refunded / cancelled） |
| `order_items` | 223,451 | 订单明细：商品、数量、单价、行金额 |

时间跨度 2025-01-01 至 2026-10-31，共约 37 万行。

## 数据中的异常

生成数据时按业务上真实会遇到的情况注入了 15 类异常，累计影响 2,880 行（`sql/01_quality.sql` 逐类统计）：

| 表 | 异常 | 行数 |
|---|---|---:|
| orders | 重复 `order_id` | 600 |
| orders | 空 `user_id` | 300 |
| orders | 空 `status` | 200 |
| orders | 空 `total_amount` | 200 |
| orders | 负 `total_amount` | 80 |
| orders | 未来日期（2027 年） | 150 |
| orders | 非法 `channel_id = 99` | 120 |
| order_items | 负 `quantity` | 400 |
| order_items | 空 `unit_price` | 100 |
| order_items | `line_amount` 与数量 × 单价不一致 | 400 |
| users | `city` 前后带空格 | 150 |
| users | `age = 999`（哨兵值） | 50 |
| users | 空 `gender` | 100 |
| products | 空 `price` | 20 |
| products | `price <= 0` | 10 |

## 清洗口径

所有分析都基于 `v_orders_clean`（`sql/02_clean_view.sql`），保证口径唯一：

1. `order_id` 重复时按 `order_date` 排序取第一条（`ROW_NUMBER()`）。
2. 剔除空 `user_id`、空 `status`、未来日期、非法 `channel_id`。
3. 金额以 `order_items` 的 `quantity × unit_price` 重算；算不出明细的订单回退到 `total_amount`。
4. 主品类取订单明细中金额最大的品类。
5. 只保留重算后金额 > 0 的订单。

清洗后 99,233 单，其中支付 86,014 单，GMV 3.88 亿元。

## 分析任务

| 脚本 | 问题 | 结果 |
|---|---|---|
| `03_channel.sql` | 各渠道 GMV、客单价、买家数 | 信息流 GMV 1.24 亿、客单价 9,197 元，均第一 |
| `04_repeat.sql` | 各渠道复购率（按注册渠道归因） | 老客推荐 85.0% 最高，信息流 51.8% 最低 |
| `05_monthly.sql` | 月度 GMV 与环比（`LAG`） | 双 11 月环比 +91.8%，为全年峰值 |
| `06_refund.sql` | 品类退款率（`CASE WHEN` + `COUNT(DISTINCT)`） | 服饰鞋包 17.9%，第二名为 9.1% |
| `07_top_products.sql` | 每个品类 GMV Top3 商品（`RANK`） | 手机数码第一名单品 307.9 万元 |
| `08_cohort_30d.sql` | 首单后 30 天复购率（自连接 + `DATEDIFF`） | 14.7%（4,930 / 33,586） |
| `09_latest_order.sql` | 每个用户最近一单（`ROW_NUMBER`） | 用户当前状态 / 流失召回名单 |
| `10_consecutive_3m.sql` | 连续 3 个月下单（月份序号 - 行号分组） | 1,444 人，占 4.3% |
| `11_channel_category.sql` | 渠道 × 品类交叉 | 信息流 × 电脑办公客单价 13,143 元最高 |

详细的数字、图表和建议见 [analysis.md](analysis.md)。

## 运行

```bash
# 1. 生成模拟数据（固定随机种子，结果可复现）
python generate_data.py

# 2. 建库建表
mysql -u root -p < create_tables.sql

# 3. 导入（处理空值/整数列后 LOAD DATA 批量导入）
python prepare_load.py
mysql -u root -p --local-infile=1 < load_all.sql
# Windows 也可以直接双击 一键导入.bat

# 4. 依次执行 sql/ 下的脚本，结果写入 results/
mysql -u root -p xiaomi_practice --batch < sql/02_clean_view.sql

# 5. 画图
python make_charts.py
```

环境：MySQL 8.0+（需要窗口函数、CTE）、Python 3.10+（pandas、numpy、Pillow）。

## 局限

- 数据是模拟的，渠道与品类的差异来自生成时的分布设定，不能外推到真实业务。
- 未做用户分层、RFM、AB 实验；退款率未区分部分退款与整单退款。
- 时间跨度 22 个月，只够做一次 618 / 双 11 的同比对照。
