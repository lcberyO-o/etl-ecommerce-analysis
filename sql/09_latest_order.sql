-- ============================================================
-- 每个用户最近一单
-- 口径：按 order_date 倒序、order_id 倒序取第一条（同一天多单时用 order_id 兜底）。
-- 输出：前 20 行示例，全量结果去掉 LIMIT 即可。
-- ============================================================

WITH ranked AS (
  SELECT order_id, user_id, order_date, total_amount,
         ROW_NUMBER() OVER (
           PARTITION BY user_id
           ORDER BY order_date DESC, order_id DESC
         ) AS rn
  FROM v_orders_clean
)
SELECT user_id, order_id, order_date, ROUND(total_amount, 2) AS total_amount
FROM ranked
WHERE rn = 1
ORDER BY user_id
LIMIT 20;
