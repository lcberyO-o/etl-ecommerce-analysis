-- ============================================================
-- 连续 3 个月下单的用户
-- 思路：先把年月压成单调的月份序号（year*12+month），
--       再用「序号 - 行号」做分组：连续月份的差值恒定。
-- 口径：只算支付订单。
-- ============================================================

WITH user_month AS (
  SELECT DISTINCT user_id,
         EXTRACT(YEAR_MONTH FROM order_date) AS ym
  FROM v_orders_clean
  WHERE status = 'paid'
),
seq AS (
  SELECT user_id,
         ym,
         (ym DIV 100) * 12 + (ym MOD 100) AS m_idx,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY ym) AS rn
  FROM user_month
),
grp AS (
  SELECT user_id, ym, m_idx - rn AS grp_key
  FROM seq
)
SELECT user_id,
       MIN(ym)     AS start_ym,
       COUNT(*)    AS months
FROM grp
GROUP BY user_id, grp_key
HAVING COUNT(*) >= 3
ORDER BY months DESC, user_id
LIMIT 20;
