-- ============================================================
-- 任务 1：数据质量盘点
-- 环境：MySQL 8.0+ / 库 xiaomi_practice
-- 目的：清洗前先量化"数据有多脏"，作为后续所有清洗口径的依据。
-- 结论：13 类问题共影响约 2,000 行，占比约 2%，必须清洗后再算指标。
-- ============================================================


-- ------------------------------------------------------------
-- 1.1 重复订单（一个 order_id 出现多次）
-- ------------------------------------------------------------
SELECT order_id, COUNT(*) AS cnt
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC;


-- ------------------------------------------------------------
-- 1.2 订单侧：空值 / 异常金额
-- ------------------------------------------------------------
SELECT COUNT(*) AS null_user_id FROM orders WHERE user_id IS NULL;
SELECT COUNT(*) AS null_status  FROM orders WHERE status IS NULL;
SELECT COUNT(*) AS null_amount  FROM orders WHERE total_amount IS NULL;
SELECT COUNT(*) AS neg_amount   FROM orders WHERE total_amount < 0;
SELECT COUNT(*) AS zero_amount  FROM orders WHERE total_amount = 0;


-- ------------------------------------------------------------
-- 1.3 订单侧：非法值（未来日期 / 不存在的渠道）
-- ------------------------------------------------------------
SELECT COUNT(*) AS future_date      FROM orders WHERE order_date > '2026-10-31';
SELECT COUNT(*) AS future_date_2027 FROM orders WHERE order_date >= '2027-01-01';
SELECT COUNT(*) AS bad_channel      FROM orders WHERE channel_id NOT IN (1, 2, 3, 4, 5, 6);
SELECT COUNT(*) AS null_channel     FROM orders WHERE channel_id IS NULL;
SELECT COUNT(*) AS null_order_date  FROM orders WHERE order_date IS NULL;


-- ------------------------------------------------------------
-- 1.4 明细侧：负数量 / 空单价 / 行金额对不上
-- ------------------------------------------------------------
SELECT COUNT(*) AS neg_quantity    FROM order_items WHERE quantity < 0;
SELECT COUNT(*) AS null_unit_price FROM order_items WHERE unit_price IS NULL;
SELECT COUNT(*) AS null_product    FROM order_items WHERE product_id IS NULL;
-- 行金额是否等于 数量 × 单价（保留 2 位，避免浮点误差误报）
SELECT COUNT(*) AS mismatch_line
FROM order_items
WHERE ABS(line_amount - quantity * unit_price) > 0.01;


-- ------------------------------------------------------------
-- 1.5 用户侧：城市空格 / 年龄哨兵值 / 空性别
-- ------------------------------------------------------------
SELECT COUNT(*) AS city_padded FROM users WHERE city <> TRIM(city);
SELECT COUNT(*) AS age_999     FROM users WHERE age = 999;
SELECT COUNT(*) AS null_gender FROM users WHERE gender IS NULL;
SELECT COUNT(*) AS null_age    FROM users WHERE age IS NULL;


-- ------------------------------------------------------------
-- 1.6 商品侧：价格为空 / 价格异常
-- ------------------------------------------------------------
SELECT COUNT(*) AS null_price FROM products WHERE price IS NULL;
SELECT COUNT(*) AS bad_price  FROM products WHERE price <= 0;
SELECT COUNT(*) AS null_cost  FROM products WHERE cost IS NULL;


-- ------------------------------------------------------------
-- 1.7 汇总：一张"问题类型 / 行数"的总账表（面试直接展示这张）
-- ------------------------------------------------------------
WITH dup AS (
  SELECT COUNT(*) AS total, COUNT(DISTINCT order_id) AS distinct_id
  FROM orders
)
SELECT '订单：重复 order_id（多出行数）' AS 问题类型, total - distinct_id AS 行数 FROM dup
UNION ALL SELECT '订单：空 user_id',        COUNT(*) FROM orders WHERE user_id IS NULL
UNION ALL SELECT '订单：空 status',         COUNT(*) FROM orders WHERE status IS NULL
UNION ALL SELECT '订单：空 total_amount',   COUNT(*) FROM orders WHERE total_amount IS NULL
UNION ALL SELECT '订单：负 total_amount',   COUNT(*) FROM orders WHERE total_amount < 0
UNION ALL SELECT '订单：未来日期',          COUNT(*) FROM orders WHERE order_date > '2026-10-31'
UNION ALL SELECT '订单：非法 channel_id',   COUNT(*) FROM orders WHERE channel_id NOT IN (1, 2, 3, 4, 5, 6)
UNION ALL SELECT '明细：负 quantity',       COUNT(*) FROM order_items WHERE quantity < 0
UNION ALL SELECT '明细：空 unit_price',     COUNT(*) FROM order_items WHERE unit_price IS NULL
UNION ALL SELECT '明细：行金额对不上',      COUNT(*) FROM order_items WHERE ABS(line_amount - quantity * unit_price) > 0.01
UNION ALL SELECT '用户：city 前后空格',     COUNT(*) FROM users WHERE city <> TRIM(city)
UNION ALL SELECT '用户：age = 999',         COUNT(*) FROM users WHERE age = 999
UNION ALL SELECT '用户：空 gender',         COUNT(*) FROM users WHERE gender IS NULL
UNION ALL SELECT '商品：空 price',          COUNT(*) FROM products WHERE price IS NULL
UNION ALL SELECT '商品：price <= 0',        COUNT(*) FROM products WHERE price <= 0;
