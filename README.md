# 模拟电商订单 ETL 与分析（个人项目）

> **重要：这是个人模拟项目，数据由脚本生成，不是真实公司数据。**
> 面试时主动说明这一点，不丢人；重点是你能讲清楚「建表 → 清洗 → SQL → 指标 → 结论」的完整方法。
> 千万不要在简历或面试里把它包装成“真实业务项目”。

---

## 0. 这个项目能帮你回答什么

- 哪个渠道的 GMV、客单价、复购率最高/最低？
- 用户复购整体怎么样？哪些渠道拉来的用户留不住？
- 哪个品类退款率异常？为什么？
- 618、双 11 对 GMV 的拉动有多大？
- 每个品类卖得最好的商品是谁？

做完后，你会得到：**5 张表、约 37 万行数据、10 条 SQL、3 张图、1 页结论、1 段能讲 3 分钟的面试项目**。

---

## 1. 数据概览

| 表 | 行数（原始） | 说明 |
|---|---:|---|
| `users.csv` | 50,000 | 用户，含注册日期、城市、年龄、性别、来源渠道 |
| `products.csv` | 800 | 商品，含品类、售价、成本 |
| `channels.csv` | 6 | 渠道字典 |
| `orders.csv` | 100,600 | 订单，含用户、日期、渠道、金额、状态 |
| `order_items.csv` | 223,451 | 订单明细，含商品、数量、单价、行金额 |

合计约 **37 万行**，时间跨度 **2025-01-01 至 2026-10-31**。

### 字段说明

**users**

| 字段 | 类型 | 说明 |
|---|---|---|
| user_id | INT | 用户 ID |
| register_date | DATE | 注册日期 |
| city | VARCHAR | 城市 |
| age | INT | 年龄 |
| gender | VARCHAR | 性别 |
| channel_id | INT | 注册来源渠道 |

**channels**

| 字段 | 类型 | 说明 |
|---|---|---|
| channel_id | INT | 渠道 ID |
| channel_name | VARCHAR | 自然流量 / 搜索广告 / 信息流 / 社交裂变 / 地推 / 老客推荐 |

**products**

| 字段 | 类型 | 说明 |
|---|---|---|
| product_id | INT | 商品 ID |
| category | VARCHAR | 品类 |
| price | DECIMAL | 售价 |
| cost | DECIMAL | 成本 |

**orders**

| 字段 | 类型 | 说明 |
|---|---|---|
| order_id | INT | 订单 ID |
| user_id | INT | 用户 ID |
| order_date | DATE | 下单日期 |
| channel_id | INT | 下单渠道 |
| total_amount | DECIMAL | 订单金额 |
| status | VARCHAR | paid / refunded / cancelled |

**order_items**

| 字段 | 类型 | 说明 |
|---|---|---|
| order_id | INT | 订单 ID |
| product_id | INT | 商品 ID |
| quantity | INT | 数量 |
| unit_price | DECIMAL | 成交单价 |
| line_amount | DECIMAL | 行金额 = quantity × unit_price |

---

## 2. 已知脏数据（练习点）

数据里故意埋了这些问题，**不要直接拿来算指标**：

- `orders`
  - 600 条重复 `order_id`
  - 300 条空 `user_id`
  - 150 条未来日期（2027 年）
  - 120 条非法 `channel_id = 99`
  - 200 条空 `status`
  - 200 条空 `total_amount`、80 条负 `total_amount`
- `order_items`
  - 400 条负 `quantity`
  - 100 条空 `unit_price`
- `users`
  - 150 条 `city` 前后带空格（如 `" 南京 "`）
  - 50 条 `age = 999`
  - 100 条空 `gender`
- `products`
  - 20 条空 `price`、10 条负 `price`

清洗口径建议（自己判断，面试要能解释）：

1. 重复订单：按 `order_id` 去重，保留一条。
2. 空 `user_id`、空 `status`、空/负 `total_amount`：剔除。
3. 未来日期、非法 `channel_id`：剔除。
4. 订单金额：优先用 `order_items` 重算 `SUM(quantity × unit_price)`，和 `total_amount` 对不上的以明细为准（或标记异常）。
5. 明细负数量、空单价：剔除后再汇总。
6. `city` 去空格、`age = 999` 置空、`price <= 0` 剔除。

---

## 3. 导入 MySQL（Navicat）

1. 打开 Navicat，连接本地 MySQL 8.0+。
2. 新建查询，执行 `create_tables.sql`（会建好库 `xiaomi_practice` 和 5 张表）。
   **不要用导入向导自动建表**：`orders` 里有重复 `order_id`，自动加唯一键会导入失败。
3. 右键某张表 →「导入向导」→ 选择对应 CSV：
   - 分隔符：逗号
   - 编码：UTF-8
   - 勾选「字段名在首行」
   - 目标表选已建好的表，导入模式选「追加」
   - 日期列 `DATE`，金额列 `DECIMAL(12,2)`，ID 列 `INT`
4. 导入顺序：`channels` → `users` → `products` → `orders` → `order_items`。
5. 验证行数：

```sql
SELECT 'users' AS t, COUNT(*) AS c FROM users
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'channels', COUNT(*) FROM channels
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;
```

6. 确认 MySQL 版本 ≥ 8.0（窗口函数需要）：`SELECT VERSION();`
7. 导入后先跑任务 1，确认空值是否被识别成 `NULL`。如果空值变成了 0，回到导入向导勾选「空字符串作为 NULL」再重新导入。

如果导入向导不方便，可以用 `LOAD DATA`（需要开启 `local_infile`）：

```sql
LOAD DATA LOCAL INFILE 'C:/Users/33079/Documents/Xiaomi实习/ETL项目重建/data/channels.csv'
INTO TABLE channels
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(channel_id, channel_name);

LOAD DATA LOCAL INFILE 'C:/Users/33079/Documents/Xiaomi实习/ETL项目重建/data/users.csv'
INTO TABLE users
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(user_id, register_date, city, age, gender, channel_id);

LOAD DATA LOCAL INFILE 'C:/Users/33079/Documents/Xiaomi实习/ETL项目重建/data/products.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, category, price, cost);

LOAD DATA LOCAL INFILE 'C:/Users/33079/Documents/Xiaomi实习/ETL项目重建/data/orders.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, user_id, order_date, channel_id, total_amount, status);

LOAD DATA LOCAL INFILE 'C:/Users/33079/Documents/Xiaomi实习/ETL项目重建/data/order_items.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, product_id, quantity, unit_price, line_amount);
```

> 路径按你电脑实际位置改；Windows 用正斜杠 `/`。
> 如果 `LOAD DATA LOCAL` 报错，先执行 `SET GLOBAL local_infile = 1;`，或者直接用 Navicat 导入向导。

---

## 4. 三天计划

### Day 1（约 3 小时）：导入 + 清洗

- 导入 5 张表。
- 做 `sql_tasks.sql` 的任务 1（数据质量盘点），把每类问题的行数查出来。
- 做任务 2（清洗视图 `v_orders_clean`）。
- 做任务 3（渠道核心指标）。
- 产出：`sql/01_quality.sql`、`sql/02_clean_view.sql`、`sql/03_channel.sql`。

### Day 2（约 4 小时）：核心分析

- 任务 4：渠道复购率。
- 任务 5：月度 GMV 与环比。
- 任务 6：品类退款率 Top3。
- 任务 7：每个品类 GMV Top3 商品。
- 任务 8：首单后 30 天复购率。
- 产出：`sql/04_*.sql` 到 `sql/08_*.sql`。

### Day 3（约 3 小时）：进阶 + 产出

- 任务 9：每个用户最近一单。
- 任务 10：连续 3 个月下单的用户。
- 任务 11：渠道 × 品类交叉。
- 做 3 张图（Excel 透视表 / Tableau / Power BI 都行）：
  1. 渠道 GMV + 客单价
  2. 月度 GMV 趋势
  3. 品类退款率
- 写 1 页结论：3 条发现 + 3 条建议。
- 建 GitHub 仓库，上传 `generate_data.py`、`sql/`、`charts/`、`README.md`、`analysis.md`；`data/` 不要上传（太大），在 `.gitignore` 里忽略。

---

## 5. SQL 任务

见同目录 `sql_tasks.sql`。共 11 个任务，按顺序做。

原则：

- 先自己写，卡住再看提示。
- 每条 SQL 都要能解释「为什么这么写」。
- 写完把结果截图/导出，放进 `analysis.md`。

---

## 6. 分析产出

### 3 张图

1. **渠道 GMV 与客单价**：柱状图（GMV）+ 折线（客单价），双轴。
2. **月度 GMV 趋势**：折线图，标出 618、双 11。
3. **品类退款率**：条形图，从高到低排序。

### 1 页结论模板

```
一、核心发现
1. 信息流渠道客单价最高（约 9,200 元），GMV 也最高（约 1.24 亿），但复购率最低（约 54%）。
2. 老客推荐渠道复购率最高（约 83%），但客单价偏低（约 3,200 元）。
3. 服饰鞋包退款率约 12.6%，显著高于其他品类（约 7%）。
4. 618 月 GMV 约为平月的 1.6 倍，双 11 月约为 2 倍。

二、建议
1. 信息流：拉新强、留存弱，建议用配件/延保/会员提升复购，而不是只加大投放。
2. 老客推荐：复购最高，建议加大老带新激励，提升客单价。
3. 服饰：排查尺码、详情页、质检和物流，降低退款率。
4. 大促：提前备货和锁定投放预算，平月做复购活动平滑波动。

三、口径说明
GMV 只算 status='paid'；退款率 = 退款订单数 / 支付订单数（按 order_id 去重）；
复购率 = 支付订单数 ≥ 2 的用户数 / 有支付订单的用户数。
```

> 上面数字是这套数据跑出来的参考值。**做完自己核对一遍再写**，面试官会追问口径。

---

## 7. 简历怎么写

不要写“真实业务项目”，写“个人模拟项目”：

```
个人项目：模拟电商订单数据 ETL 与分析（2026.11）
- 用 Python 生成 5 万用户、10 万订单、22 万条明细的模拟数据集（5 张表），覆盖 2025.01–2026.10；
- 用 SQL 完成重复、空值、异常值、未来日期、金额不一致清洗，构建订单宽表视图；
- 用 JOIN / CTE / 窗口函数计算渠道 GMV、客单价、复购率、月度环比、品类退款率与商品 TopN；
- 输出 3 张可视化与 1 页结论：信息流客单价最高但复购最低、服饰退款率显著偏高、618/双 11 为 GMV 高峰。
```

面试被问“数据哪来的”，就这么答：

> 数据是我用 Python 按真实电商表结构模拟的，因为拿不到公司真实数据。我故意埋了重复、空值、异常值，重点展示我从建表、清洗、SQL 到结论的完整方法。模拟数据的好处是变量可控，我能验证自己的分析逻辑。

---

## 8. 面试怎么讲

### 30 秒版

> 我做了一个模拟电商订单分析项目。因为拿不到真实业务数据，我用 Python 生成了 5 万用户、10 万订单、22 万条明细，包含 5 张表，并故意埋了重复、空值、异常值。然后用 SQL 清洗、建宽表，算了渠道 GMV、客单价、复购率、退款率和月度趋势，最后用 3 张图输出结论。最有意思的发现是信息流渠道客单价最高但复购最低。

### 3 分钟版

1. **背景**：想练完整的 ETL + 分析流程，但没有真实数据权限。
2. **目标**：回答渠道质量、用户复购、品类退款、大促效果四个问题。
3. **做法**：
   - 设计 5 张表（用户、商品、渠道、订单、明细）；
   - 用 Python 生成数据，按业务规则设置渠道/品类/价格/状态分布；
   - 用 SQL 清洗（去重、空值、异常、金额重算），建 `v_orders_clean`；
   - 用 JOIN、CTE、窗口函数算指标；
   - 用 Excel/Tableau 出图，写结论。
4. **发现**：3 条（见上）。
5. **反思**：数据是模拟的，结论不能直接外推；如果重做，会加真实 AB test、用户分层、复购预测。

### 常见追问

| 问题 | 回答要点 |
|---|---|
| 数据怎么生成的？ | Python + numpy/pandas，按业务规则设定分布；订单明细由商品和数量汇总 |
| 为什么用模拟数据？ | 没有真实数据权限；模拟数据可控制变量，重点练方法 |
| GMV 口径？ | 只算 `status='paid'`，剔除退款/取消 |
| 退款率口径？ | 退款订单数 / 支付订单数，按 `order_id` 去重，避免明细行重复计算 |
| 复购率口径？ | 支付订单数 ≥ 2 的用户 / 有支付订单的用户 |
| 哪条 SQL 最难？ | 连续 3 个月下单、首单后 30 天复购（窗口 + 自连接） |
| 如果重做？ | 接真实数据源、加调度、做 AB test、用户分层 |

---

## 9. 底线

1. **不要写“真实业务”**，不要写你没跑过的数字。
2. **每一行 SQL 你都要能解释**，面试可能让你现场手写。
3. AI 可以帮你查语法、生成数据、检查报错，但**不能替你说**。
4. 3 天做不完就做核心 5 个任务（1、2、3、4、6），别贪多。
5. 做完把 GitHub 链接放简历上，比写“熟悉 SQL”有用得多。
