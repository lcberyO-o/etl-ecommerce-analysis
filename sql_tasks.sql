-- ============================================================
-- 模拟电商订单 ETL 与分析：SQL 任务清单
-- 环境：MySQL 8.0+（窗口函数、CTE）
-- 表：channels / users / products / orders / order_items
-- 先执行 create_tables.sql，再导入 data/ 下的 CSV。
-- 建议：每个任务单独存一个 .sql 文件，结果截图放进 analysis.md。
-- ============================================================


-- ============================================================
-- 任务 1：数据质量盘点
-- 目标：清洗前先证明“数据有多脏”，输出每类问题的行数。
-- ============================================================

-- 1.1 重复订单（示例，可直接跑）
SELECT order_id, COUNT(*) AS cnt
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

-- 1.2 自己写：空 user_id、空 status、空 total_amount、负 total_amount
-- 1.3 自己写：未来日期（> 2026-10-31）、非法 channel_id（= 99）
-- 1.4 自己写：order_items 负 quantity、空 unit_price
-- 1.5 自己写：users city 前后空格、age = 999、gender 为空
-- 1.6 自己写：products price 为空或 <= 0

-- 提示：每类问题用 SELECT COUNT(*) 包一层，最后 UNION ALL 成一张“问题类型 / 行数”表。


-- ============================================================
-- 任务 2：构建清洗视图 v_orders_clean
-- 目标：后面所有分析都基于这个视图，保证口径一致。
-- 要求：
--   - 按 order_id 去重
--   - 剔除空 user_id / 空 status / 未来日期 / 非法 channel_id
--   - 金额优先用 order_items 重算（quantity * unit_price），重算不出再用 total_amount
--   - 关联 channel_name、主品类 main_category
--   - 只保留金额 > 0 的订单
-- ============================================================

-- 先自己写。卡住再看下面的参考写法。
-- 参考写法（MySQL 8.0）：

CREATE OR REPLACE VIEW v_orders_clean AS
WITH dedup AS (
  SELECT o.*,
         ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY o.order_date) AS rn
  FROM orders o
),
valid AS (
  SELECT *
  FROM dedup
  WHERE rn = 1
    AND user_id IS NOT NULL
    AND status IS NOT NULL
    AND order_date BETWEEN '2025-01-01' AND '2026-10-31'
    AND channel_id IN (1, 2, 3, 4, 5, 6)
),
item_amt AS (
  SELECT order_id,
         SUM(quantity * unit_price) AS calc_amount
  FROM order_items
  WHERE quantity > 0
    AND unit_price IS NOT NULL
  GROUP BY order_id
),
item_cat AS (
  SELECT oi.order_id,
         p.category,
         SUM(oi.quantity * oi.unit_price) AS amt,
         ROW_NUMBER() OVER (
           PARTITION BY oi.order_id
           ORDER BY SUM(oi.quantity * oi.unit_price) DESC
         ) AS rn
  FROM order_items oi
  JOIN products p ON oi.product_id = p.product_id
  WHERE oi.quantity > 0
    AND oi.unit_price IS NOT NULL
  GROUP BY oi.order_id, p.category
)
SELECT v.order_id,
       v.user_id,
       v.order_date,
       v.channel_id,
       c.channel_name,
       ic.category AS main_category,
       COALESCE(a.calc_amount, v.total_amount) AS total_amount,
       v.status
FROM valid v
LEFT JOIN channels c   ON v.channel_id = c.channel_id
LEFT JOIN item_amt a   ON v.order_id = a.order_id
LEFT JOIN item_cat ic  ON v.order_id = ic.order_id AND ic.rn = 1
WHERE COALESCE(a.calc_amount, v.total_amount) > 0;

-- 验证：
SELECT COUNT(*) AS clean_orders FROM v_orders_clean;
SELECT status, COUNT(*) FROM v_orders_clean GROUP BY status;


-- ============================================================
-- 任务 3：渠道核心指标（示例，可先照着写一遍）
-- 输出：渠道、支付订单数、买家数、GMV、客单价
-- ============================================================

SELECT channel_name,
       COUNT(DISTINCT order_id) AS orders,
       COUNT(DISTINCT user_id)  AS buyers,
       ROUND(SUM(total_amount), 2) AS gmv,
       ROUND(SUM(total_amount) / COUNT(DISTINCT order_id), 2) AS aov
FROM v_orders_clean
WHERE status = 'paid'
GROUP BY channel_name
ORDER BY gmv DESC;


-- ============================================================
-- 任务 4：各渠道复购率
-- 定义：支付订单数 >= 2 的用户数 / 有支付订单的用户数
-- 注意：先想清楚按“用户注册渠道”还是“订单渠道”归因，在注释里写明。
-- ============================================================

-- 提示：
-- 1) 先按 user_id 统计支付订单数
-- 2) CASE WHEN cnt >= 2 THEN 1 ELSE 0 END 标记复购
-- 3) 再按渠道求平均
-- 4) 用 ROUND(..., 4) 保留 4 位，方便看差异


-- ============================================================
-- 任务 5：月度 GMV 与环比
-- 输出：月份、GMV、上月 GMV、环比增长率
-- ============================================================

-- 提示：DATE_FORMAT(order_date, '%Y-%m') 按月分组；LAG(gmv) OVER (ORDER BY month) 取上月；
--       环比 = (gmv - prev) / prev * 100，注意除零。


-- ============================================================
-- 任务 6：品类退款率 Top3
-- 定义：退款订单数 / 支付订单数（都按 order_id 去重）
-- ============================================================

-- 提示：COUNT(DISTINCT CASE WHEN status = 'refunded' THEN order_id END)
--       / COUNT(DISTINCT CASE WHEN status = 'paid' THEN order_id END)
--       按 main_category 分组，HAVING 支付订单数 >= 100 避免小样本。


-- ============================================================
-- 任务 7：每个品类 GMV Top3 商品
-- 输出：品类、商品、GMV、排名
-- ============================================================

-- 提示：order_items JOIN products JOIN v_orders_clean（只取 paid）；
--       SUM(quantity * unit_price) 算商品 GMV；
--       RANK() OVER (PARTITION BY category ORDER BY gmv DESC)；
--       最后筛 rn <= 3。


-- ============================================================
-- 任务 8：用户首单后 30 天内复购率
-- 定义：首单后 30 天内又有支付订单的用户 / 有首单的用户
-- ============================================================

-- 提示：
-- 1) 每个用户 MIN(order_date) 作为首单日期
-- 2) 自连接后续订单，DATEDIFF(后续下单日, 首单日) BETWEEN 1 AND 30
-- 3) 去重用户后算比例
-- 4) 可选：按渠道拆分


-- ============================================================
-- 任务 9：每个用户最近一单
-- 输出：user_id、order_id、order_date、total_amount
-- ============================================================

-- 提示：ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_date DESC, order_id DESC) = 1


-- ============================================================
-- 任务 10：连续 3 个月下单的用户
-- 输出：user_id、连续段起始月、连续月数
-- ============================================================

-- 提示：
-- 1) 先做 user_id + 月份的去重
-- 2) ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY 月份)
-- 3) 用“月份序号 - rn”分组，连续月份的差值相同
-- 4) HAVING COUNT(*) >= 3
-- MySQL 里可用 EXTRACT(YEAR_MONTH FROM order_date) 得到 202501 这样的整数。


-- ============================================================
-- 任务 11：渠道 × 品类交叉分析
-- 输出：渠道、品类、GMV、客单价、退款率
-- ============================================================

-- 提示：GROUP BY channel_name, main_category；
--       GMV / COUNT(DISTINCT order_id) 做客单价；
--       退款率同任务 6；
--       HAVING COUNT(DISTINCT order_id) >= 50，避免小样本结论。


-- ============================================================
-- 交付清单
-- ============================================================
-- sql/01_quality.sql
-- sql/02_clean_view.sql
-- sql/03_channel.sql
-- sql/04_repeat.sql
-- sql/05_monthly.sql
-- sql/06_refund.sql
-- sql/07_top_products.sql
-- sql/08_cohort_30d.sql
-- sql/09_latest_order.sql
-- sql/10_consecutive_3m.sql
-- sql/11_channel_category.sql
--
-- 每写完一条，把结果截图或导出 CSV，放进 analysis.md，并写一句结论。
-- 卡住可以把 SQL 和报错发我，我帮你看。
